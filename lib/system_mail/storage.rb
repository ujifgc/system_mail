require 'tempfile'
require 'fileutils'

module SystemMail
  class Storage
    def initialize(path)
      @path = path
      @io = StringIO.new
      @mutex = Mutex.new
    end

    def write
      @mutex.synchronize do
        yield @io
      end
    end

    def capture
      @mutex.synchronize do
        ensure_tempfile
        @io.close
        yield @io.path
        @io.open
      end
    end

    def done
      @io.close
      @io.unlink if @io.kind_of?(Tempfile)
      @io = StringIO.new
    end

    private

    def ensure_tempfile
      return if @io.kind_of?(Tempfile)
      tempfile = create_tempfile
      tempfile.puts @io.string
      @io = tempfile
    end

    def create_tempfile
      temp_directory = File.join(@path, 'system_mail')
      FileUtils.mkdir_p(temp_directory)
      Tempfile.new('storage', temp_directory, :mode => IO::APPEND)
    end
  end
end
