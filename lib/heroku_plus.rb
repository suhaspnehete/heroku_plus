require "optparse"
require "yaml"

class HerokuPlus
  VERSION_FILE = File.join File.dirname(__FILE__), "..", "VERSION.yml"
  
  # Execute.
  def self.run args = ARGV
    hp = HerokuPlus.new
    hp.parse_args args
  end

  def initialize
    # Load defaults.
    @heroku_home = File.join ENV["HOME"], ".heroku"
    @heroku_credentials = "credentials"
    @ssh_home = File.join ENV["HOME"], ".ssh"
    @ssh_identity = "id_rsa"
    @settings_file = File.join @heroku_home, "settings.yml"
    # Override defaults with custom settings (if found).
    if File.exists? @settings_file
      settings_file = YAML::load_file @settings_file
      @heroku_credentials = settings_file[:heroku_credentials]
      @ssh_identity = settings_file[:ssh_identity]
    end

    # Load version information.
    if File.exists? VERSION_FILE
      version_file = YAML::load_file VERSION_FILE
      @version = [version_file[:major], version_file[:minor], version_file[:patch]] * '.'
    else
      puts "ERROR: Unable to load version information."
    end
  end

  # Read and parse the supplied command line arguments.
  def parse_args args = ARGV
    # Configure.
    parser = OptionParser.new do |o|
      o.banner = "Usage: herokup [options]"

      o.on_tail "-s ", "--switch ACCOUNT", String, "Switch Heroku credentials and SSH identity to specified account." do |account|
        switch_credentials account
        switch_identity account
        print_account
        exit
      end
    
      o.on_tail "-a", "--account", "Show the current Heroku credentials and SSH identity." do
        print_account and exit
      end

      o.on_tail "-h", "--help", "Show this help message." do
        puts parser and exit
      end

      o.on_tail("-v", "--version", "Show the current version.") do
        print_version and exit
      end      
    end
    
    # Parse.
    begin
      parser.parse! args
    rescue OptionParser::InvalidOption => error
      puts error.message.capitalize
    rescue OptionParser::MissingArgument => error
      puts error.message.capitalize
    end
  end

  # Switches Heroku credentials to given account.
  # ==== Parameters
  # * +account+ - Required. The account to switch to. Defaults to "unknown".
  def switch_credentials account = "unknown"
    account_path = File.join @heroku_home, account + '.' + @heroku_credentials
    credentials_path = File.join @heroku_home, @heroku_credentials
    puts "\nSwitching Heroku credentials to \"#{account}\" account..."
    if File.exists? account_path
      system "rm -f #{credentials_path}"
      system "ln -s #{account_path} #{credentials_path}"
    else
      puts "ERROR: Heroku account does not exist!"
    end
  end
  
  # Switches SSH identity to given account.
  # ==== Parameters
  # * +account+ - Required. The account to switch to. Defaults to "unknown".
  def switch_identity account = "unknown"
    old_identity_path = File.join @ssh_home, @ssh_identity
    old_identity_pub_path = File.join @ssh_home, @ssh_identity + ".pub"
    new_identity_path = File.join @ssh_home, account + '.identity'
    new_identity_pub_path = File.join @ssh_home, account + '.identity.pub'
    puts "\nSwitching Heroku SSH identity to \"#{account}\" account..."
    if File.exists? new_identity_path
      system "rm -f #{old_identity_path}"
      system "rm -f #{old_identity_pub_path}"
      system "ln -s #{new_identity_path} #{old_identity_path}"
      system "ln -s #{new_identity_pub_path} #{old_identity_pub_path}"
    else
      puts "ERROR: Heroku account does not exist!"
    end
  end
  
  # Print active account information.
  def print_account
    credentials_path = File.join @heroku_home, @heroku_credentials
    ssh_path = File.join @ssh_home, @ssh_identity
    if File.exists?(credentials_path) && File.exists?(ssh_path)
      puts "\nCurrent Heroku account is:\n\n"
      puts "Account:         #{current_heroku_account credentials_path}" 
      puts "Password:        #{'*' * current_heroku_password(credentials_path).size}"
      puts "Source (Heroku): #{credentials_path}"
      puts "Source (SSH):    #{ssh_path}\n\n"
    else
      puts "ERROR: Heroku credentials and/or SSH identity not found!"
    end    
  end
  
  # Print version information.
  def print_version
    puts "Heroku Plus " + @version
  end
  
  private
  
  # Answers the current Heroku account name of the given credentials file.
  # ==== Parameters
  # * +file+ - Required. The credentials file from which to read the account name from.
  def current_heroku_account file
    open(file, 'r').readlines.first
  end
  
  # Answers the current Heroku password of the given credentials file.
  # ==== Parameters
  # * +file+ - Required. The credentials file from which to read the password from.
  def current_heroku_password file
    open(file, 'r').readlines.last
  end
end
