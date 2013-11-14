require 'tempfile'
require 'fileutils'

module SystemMail
  class Storage
    def initialize(path = nil)
      @tmpdir = path || Dir.tmpdir
      @io = StringIO.new
    end

    def write
      yield @io
    end

    def capture
      ensure_tempfile
      @io.close
      yield @io.path
      @io.open
    end

    def clear
      @io.close
      @io.unlink if @io.kind_of?(Tempfile)
      @io = StringIO.new
    end

    private

    def ensure_tempfile
      return if @io.kind_of?(Tempfile)
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
