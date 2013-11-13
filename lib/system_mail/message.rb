require 'tempfile'
require 'base64'

module SystemMail
  class Message
    SYSTEM_COMMANDS = {
      :sendmail => '/usr/sbin/sendmail -t',
      :base64 => 'base64',
      :file => 'file --mime-type --mime-encoding -b',
    }.freeze

    def initialize(options={})
      @text = {}
      @to = []
      %W(text html enriched from to subject files).each do |option|
        name = option.to_sym
        send(name, options[name])
      end
    end

    def deliver
      validate
      write_headers
      write_message
      `#{settings[:sendmail]} < #{message_path}`
      @message_file.unlink
    end

    def settings
      @settings ||= SYSTEM_COMMANDS.dup
    end

    private

    EOLN = "\n"
    BASE64_SIZE = 76
    UTF8_SIZE = 998

    def text(input)
      @text['text'] = input
    end

    def enriched(input)
      @text['enriched'] = input
    end

    def html(input)
      @text['html'] = input
    end

    def from(input)
      @from = input
    end

    def to(input)
      @to += Array(input)
    end

    def subject(input)
      @subject = input
    end

    def files(input)
      Array(input).each do |file|
        add_file file
      end
    end

    def add_file(input)
      attachments << input
    end

    def attachments
      @attachments ||= []
    end

    def write_message
      if attachments.any?
        multipart :mixed do |boundary|
          write_part boundary
          write_body
          attachments.each do |attachment|
            write_part boundary
            write_file attachment
          end
        end
      else
        write_body
      end
    end

    def write_body
      case @text.length
      when 0
        nil
      when 1
        data, type = @text.first
        write_content data, "text/#{type}"
      else
        multipart :alternative do |boundary|
          %w[text enriched html].each do |type|
            data = @text[type] || next
            write_part boundary
            write_content data, "text/#{type}"
          end
        end
      end
    end

    def write_content(data, content_type)
      if data.bytesize < UTF8_SIZE || !data.lines.any?{ |line| line.bytesize > UTF8_SIZE }
        write_8bit(data, content_type)
      else
        write_base64(data, content_type)
      end
    end

    def multipart(type)
      boundary = new_boundary(type)
      append_message do |file|
        file << "Content-Type: multipart/#{type}; boundary=\"#{boundary}\"" << EOLN
      end
      yield boundary
      write_part boundary, :end
    end

    def write_headers
      append_message do |file|
        file << "From: #{@from}" << EOLN  if @from
        file << "To: #{@to.join(', ')}" << EOLN
        file << "Subject: #{encode_subject}" << EOLN
      end
    end

    def write_part(boundary, type = :begin)
      append_message do |file|
        file << EOLN
        file << "--#{boundary}" << (type == :end ? '--' : '') << EOLN
      end
    end

    def write_base64(data, content_type)
      append_message do |file|
        file << "Content-Type: #{content_type}; charset=#{data.encoding}" << EOLN
        file << "Content-Transfer-Encoding: base64" << EOLN
        file << EOLN
        Base64.strict_encode64(data).each_slice(BASE64_SIZE) do |line|
          file << line << EOLN
        end
      end
    end

    def write_8bit(data, content_type)
      append_message do |file|
        file << "Content-Type: #{content_type}; charset=#{data.encoding}" << EOLN
        file << "Content-Transfer-Encoding: 8bit" << EOLN
        file << EOLN
        file << data << EOLN
      end
    end

    def write_file(attachment)
      path = case attachment
      when String
        fail Errno::ENOENT, attachment  unless File.file?(attachment)
        fail Errno::EACCES, attachment  unless File.readable?(attachment)
        attachment
      when File
        attachment.path
      else
        fail ArgumentError, 'attachment must be File or String of file path'
      end
      write_base64_file path
    end

    def write_base64_file(path)
      append_message do |file|
        file << "Content-Type: #{read_mime(path)}" << EOLN
        file << "Content-Transfer-Encoding: base64" << EOLN
        file << "Content-Disposition: attachment; filename=\"#{File.basename(path)}\"" << EOLN
        file << EOLN
      end
      `#{settings[:base64]} '#{path}' >> #{message_path}`
    end

    def read_mime(path)
      `#{settings[:file]} '#{path}'`.strip
    end

    def validate
      fail ArgumentError, "Header 'To:' is empty" if @to.empty?
      warn 'Message body is empty' if @text.empty?
    end

    def new_boundary(type)
      rand(36**6).to_s(36).rjust(20,type.to_s)
    end

    def encode_subject
      @subject.ascii_only? ? @subject : ("=?UTF-8?B?" << Base64.strict_encode64(@subject) << "?=")
    end

    def append_message
      File.open(message_path, 'a') do |file|
        yield file
      end
    end

    def message_path
      @message_path ||= begin
        @message_file = Tempfile.new('system_mail')
        @message_file.close
        @message_file.path
      end
    end
  end
end
