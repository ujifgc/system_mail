require 'base64'
require 'system_mail/storage'

module SystemMail
  class Message
    BASE64_SIZE = 76
    UTF8_SIZE = 998
    SETTINGS = {
      :sendmail => '/usr/sbin/sendmail -t',
      :base64 => 'base64',
      :file => 'file --mime-type --mime-encoding -b',
      :storage => ENV['TMP'] || '/tmp',
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
      storage.capture do |message_path|
        `#{settings[:sendmail]} < #{message_path}`
      end
      storage.done
      nil
    end

    def settings
      @settings ||= SETTINGS.dup
    end

    private

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

    def storage
      @storage ||= Storage.new(settings[:storage])
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
        write_8bit data, content_type
      else
        write_base64 data, content_type
      end
    end

    def multipart(type)
      boundary = new_boundary(type)
      storage.write do |io|
        io.puts "Content-Type: multipart/#{type}; boundary=\"#{boundary}\""
      end
      yield boundary
      write_part boundary, :end
    end

    def write_headers
      storage.write do |io|
        io.puts "From: #{@from}"  if @from
        io.puts "To: #{@to.join(', ')}"
        io.puts "Subject: #{encode_subject}"
      end
    end

    def write_part(boundary, type = :begin)
      storage.write do |io|
        io.puts
        io.puts "--#{boundary}#{type == :end ? '--' : ''}"
      end
    end

    def write_base64(data, content_type)
      storage.write do |io|
        io.puts "Content-Type: #{content_type}; charset=#{data.encoding}"
        io.puts "Content-Transfer-Encoding: base64"
        io.puts
        Base64.strict_encode64(data).each_slice(BASE64_SIZE) do |line|
          io.puts line
        end
      end
    end

    def write_8bit(data, content_type)
      storage.write do |io|
        io.puts "Content-Type: #{content_type}; charset=#{data.encoding}"
        io.puts "Content-Transfer-Encoding: 8bit"
        io.puts
        io.puts data
      end
    end

    def write_file(attachment)
      file_path = case attachment
      when String
        fail Errno::ENOENT, attachment  unless File.file?(attachment)
        fail Errno::EACCES, attachment  unless File.readable?(attachment)
        attachment
      when File
        attachment.path
      else
        fail ArgumentError, 'attachment must be File or String of file path'
      end
      write_base64_file file_path
    end

    def write_base64_file(file_path)
      storage.write do |io|
        io.puts "Content-Type: #{read_mime(file_path)}"
        io.puts "Content-Transfer-Encoding: base64"
        io.puts "Content-Disposition: attachment; filename=\"#{File.basename(file_path)}\""
        io.puts
      end
      storage.capture do |message_path|
        `#{settings[:base64]} '#{file_path}' >> #{message_path}`
      end
    end

    def read_mime(file_path)
      `#{settings[:file]} '#{file_path}'`.strip
    end

    def validate
      fail ArgumentError, "Header 'To:' is empty" if @to.empty?
      warn 'Message body is empty' if @text.empty?
    end

    def new_boundary(type)
      rand(36**6).to_s(36).rjust(20,type.to_s)
    end

    def encode_subject
      @subject.ascii_only? ? @subject : "=?UTF-8?B?#{Base64.strict_encode64 @subject}?="
    end
  end
end
