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
        print_info
        exit
      end
    
      o.on_tail "-i", "--info", "Show the current Heroku credentials and SSH identity." do
        print_info and exit
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
  # * +account+ - Required. The account name to switch to. Defaults to "unknown".
  def switch_credentials account = "unknown"
    account_file = File.join @heroku_home, account + '.' + @heroku_credentials
    credentials_file = File.join @heroku_home, @heroku_credentials
    puts "\nSwitching Heroku credentials to \"#{account}\" account..."
    if valid_file? account_file
      system "rm -f #{credentials_file}"
      system "ln -s #{account_file} #{credentials_file}"
    else
      puts "ERROR: Heroku account does not exist!"
    end
  end
  
  # Switches SSH identity to given account.
  # ==== Parameters
  # * +account+ - Required. The account name to switch to. Defaults to "unknown".
  def switch_identity account = "unknown"
    old_private_file = File.join @ssh_home, @ssh_identity
    old_public_file = File.join @ssh_home, @ssh_identity + ".pub"
    new_private_file = File.join @ssh_home, account + ".identity"
    new_public_file = File.join @ssh_home, account + ".identity.pub"
    puts "\nSwitching Heroku SSH identity to \"#{account}\" account..."
    if valid_file?(new_private_file) && valid_file?(new_public_file)
      system "rm -f #{old_private_file}"
      system "rm -f #{old_public_file}"
      system "ln -s #{new_private_file} #{old_private_file}"
      system "ln -s #{new_public_file} #{old_public_file}"
    else
      puts "ERROR: SSH identity does not exist!"
    end
  end
  
  # Prints active account information.
  def print_info
    credentials_file = File.join @heroku_home, @heroku_credentials
    ssh_private_file = File.join @ssh_home, @ssh_identity
    ssh_public_file = File.join @ssh_home, @ssh_identity + ".pub"
    if valid_file?(credentials_file) && valid_file?(ssh_private_file) && valid_file?(ssh_public_file)
      puts "\nInformation for current Heroku \"#{current_heroku_account credentials_file}\" account is:\n\n"
      puts "Account:              #{current_heroku_account credentials_file}" 
      puts "Password:             #{'*' * current_heroku_password(credentials_file).size}"
      puts "Source (Heroku):      #{credentials_file}"
      puts "Source (SSH private): #{ssh_private_file}"
      puts "Source (SSH public):  #{ssh_public_file}\n\n"
    else
      puts "ERROR: Heroku account credentials and/or SSH identity not found!"
    end
  end
  
  # Prints version information.
  def print_version
    puts "Heroku Plus " + @version
  end
  
  private

  # Answers whether the file exists or not and prints an error message when not found.
  # ==== Parameters
  # * +file+ - Required. The file to validate.
  def valid_file? file
    File.exists?(file) ? true : ("ERROR: File does not exist: #{file}." and false)
  end

  # Answers the current Heroku account name of the given credentials file.
  # ==== Parameters
  # * +file+ - Required. The credentials file from which to read the account name from.
  def current_heroku_account file
    open(file, 'r').readlines.first.strip if valid_file?(file)
  end
  
  # Answers the current Heroku password of the given credentials file.
  # ==== Parameters
  # * +file+ - Required. The credentials file from which to read the password from.
  def current_heroku_password file
    open(file, 'r').readlines.last.strip if valid_file?(file)
  end
end
