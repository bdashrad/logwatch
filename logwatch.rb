require 'pp'
require 'rbconfig'
include RbConfig

# watch w3c logs and alert on chagnes
class LogWatch
  def initialize
    @os = RbConfig::CONFIG['host_os'] # string with OS name
    load_os_gems
  end

  def load_os_gems
    case @os
    when (/bsd|darwin/)
      require 'rb-kqueue'
    when (/linux/)
      require 'rb-inotify'
    end
  end

  # open the file and watch with inotify
  def tail_file(filename)
    open(filename) do |file|
      file.seek(0, IO::SEEK_END)
      case @os
      when (/bsd|darwin/)
        queue = KQueue::Queue.new
        queue.watch_file(filename, :extend) do
          yield file.read
        end
        queue.run
      when (/linux/)
        queue = INotify::Notifier.new
        queue.watch(filename, :modify) do
          yield file.read
        end
        queue.run
      else
        loop do
          changes = file.read
          unless changes.empty? yield changes
          end
          sleep 1.0
        end
      end
    end
  end
end

def watch_logs
  log = LogWatch.new
  log_format = /\A(?<ip>\S+) (?<identity>\S+) (?<user>\S+) \[(?<time>[^\]]+)\] "(?<verb>[A-Z]+) (?<url>\S+) (?<version>\S+?)" (?<status>\d+) (?<bytes>\S+)/
  log.tail_file(ARGV.first) do |data|
    unless data.strip == ''
      logparts = log_format.match(data)
      section = logparts['url'].gsub(/(\/\w+).*/, '\1')
      logentry = Hash[logparts.names.zip(logparts.captures)]
      logentry['section'] = section
      pp logentry
      @loglines.push(logentry)
    end
  end
end

@loglines = []
watch_logs
