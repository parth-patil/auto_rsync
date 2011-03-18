require 'em-dir-watcher'
require 'getoptlong'

class AutoRsync
	attr_accessor :watch_dir, :remote_host, :remote_dir

  #@TODO make the file types to watch also an input argument
	FILE_TYPES_TO_WATCH = ['*.rb','*.sh','*.php','*.inc','*.json','*.css','*.js','*.tpl']

	def initialize(watch_dir, remote_dir, remote_host)
    puts "Setting watch dir to #{watch_dir}"

    check_prereqs

    @watch_dir = watch_dir
		@remote_host = remote_host
    @remote_dir = remote_dir
	end

	def run
		EM.run {
	 		dw = EMDirWatcher.watch(@watch_dir, :include_only => FILE_TYPES_TO_WATCH) do |paths|
				paths.each do |path|
					full_path = @watch_dir + path
					
		 			if File.exists? full_path 
						time_str = get_time_str
						puts "#{time_str} syncing \"#{full_path}\" to remote ...."
						sync_to_remote full_path
		 			else
						puts "Deleted: #{path}"
					end
				end
			end
		puts "EventMachine running..."
 	}
	end

	private
  # checks if rsync exists
  def check_prereqs
    cmd_out = `which rsync`
    if cmd_out.strip == ''
      puts "Error : rsync not found."
      exit
    end
  end

	def sync_to_remote(file_path)
		# construct the local path
		# P.S need to clone as the slice! call made later modifies the string file_path
		# and all reference to the same string object
		local_absolute_path = file_path.clone

		#construct the remote path
		remote_relative_path = file_path
		remote_relative_path.slice! @watch_dir
		remote_absolute_path = @remote_host + ':' + @remote_dir + remote_relative_path
		
		# rsync the file
		cmd = "rsync -a #{local_absolute_path} #{remote_absolute_path} "
		cmd_output = `#{cmd}`
    if cmd_output.strip != ''
      puts cmd_output
    end

	end

	def get_time_str
		time = Time.new
		return "#{time.hour}:#{time.min}:#{time.sec}"
	end
end


def print_usage
  puts <<-USAGE
ruby auto_rsync.rb --local_dir /local/dir/to/watch --remote_dir /remote/dir --remote_host myhost

-h, --help:
  show help

-l, --local_dir:
  local dir to watch for changes

-r, --remote_dir:
  remote dir to sync the file to

-s, --remote_host:
  remote host to sync files to
USAGE

end

local_dir = '';
remote_dir = '';
remote_host = '';

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--local_dir', '-l', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--remote_dir', '-r', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--remote_host', '-s', GetoptLong::REQUIRED_ARGUMENT ]
    )

opts.each do |opt, arg|
      case opt
        when '--help'
          print_usage
          exit
        when '--local_dir'
          local_dir = arg
        when '--remote_dir'
          remote_dir = arg
        when '--remote_host'
          remote_host = arg

      end
  end

if (local_dir == '' || remote_dir == '' || remote_host == '')
  puts "Missing required arguments (try --help)"
  exit
end

trap("SIGINT") { puts "good bye!"; exit! }
auto_rsync = AutoRsync.new(local_dir, remote_dir, remote_host)
auto_rsync.run
