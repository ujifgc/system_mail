require 'tempfile'
require 'fileutils'

module SystemMail
  ##
  # A class to store string data either in StringIO or in Tempfile.
  #
  class Storage
    def initialize(path = nil)
      @tmpdir = path || Dir.tmpdir
      @io = StringIO.new
    end

    def puts(data = nil)
      @io.puts(data)
    end

    def read
      if file?
        capture do |file_path|
          File.read file_path
        end
      else
        @io.string.dup
      end
    end

    def capture
      ensure_tempfile
      @io.close
      yield @io.path
      @io.open
    end

    def file?
      @io.kind_of?(Tempfile)
    end

    def clear
      @io.close
      @io.unlink if file?
    end

    private

    def ensure_tempfile
      return if file?
      tempfile = create_tempfile
      tempfile.puts @io.string if @io.size > 0
      @io = tempfile
    end

    def create_tempfile
      temp_directory = File.join(@tmpdir, 'system_mail')
      FileUtils.mkdir_p(temp_directory)
      Tempfile.new('storage', temp_directory, :mode => IO::APPEND)
    end
  end
end
