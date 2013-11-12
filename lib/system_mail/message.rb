require 'tempfile'
require 'digest/md5'
require 'base64'

module SystemMail
  class Message
    EOLN = "\n"

    def initialize(options={})
      %W(text html from to subject files).each do |option|
        name = option.to_sym
        send(name, options[name])
      end
    end

    def deliver
      write_headers
      write_message
      `/usr/sbin/sendmail -t < #{message_path}`
      @message_file.unlink
    end

    private

    def message_path
      @message_path ||= begin
        @message_file = Tempfile.new('system_mail')
        @message_file.close
        @message_file.path
      end
    end

    def text(input)
      @text = input
    end

    def html(input)
      @html = input
    end

    def from(input)
      @from = input
    end

    def to(input)
      @to = input
    end

    def subject(input)
      @subject = input
    end

    def files(input)
      Array(input).each do |file|
        attachments << file
      end
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

    def multipart(type)
      boundary = "#{type}_#{get_boundary}"
      append_message do |f|
        f.write "Content-Type: multipart/#{type}; boundary=\"#{boundary}\"" << EOLN
      end
      yield boundary
      write_part boundary, true
    end

    def write_headers
      append_message do |f|
        f.write "From: #{@from}" << EOLN
        f.write "To: #{@to}" << EOLN
        f.write "Subject: =?UTF-8?B?" << Base64.strict_encode64(@subject) << "?=" << EOLN
      end
    end

    def write_body
      if @html.nil?
        write_text
      else
        multipart :alternative do |boundary|
          write_part boundary
          write_text
          write_part boundary
          write_html
        end
      end
    end

    def write_part(boundary, finish = nil)
      append_message do |f|
        f.write EOLN
        f.write "--#{boundary}"
        f.write '--' if finish
        f.write EOLN
      end
    end

    def write_text
      write_utf8 @text, 'text/plain'
    end

    def write_html
      write_utf8 @html, 'text/html'
    end

    def write_utf8(data, content_type)
      if data.lines.any?{ |l| l.bytesize > 998 }
        write_base64(data, content_type)
      end
      append_message do |f|
        f.write "Content-Type: #{content_type}; charset=#{data.encoding}" << EOLN
        f.write "Content-Transfer-Encoding: 8bit" << EOLN << EOLN
        f.write data
        f.write EOLN
      end
    end

    def write_base64(data, content_type)
      append_message do |f|
        f.write "Content-Type: #{content_type}; charset=#{data.encoding}" << EOLN
        f.write "Content-Transfer-Encoding: base64" << EOLN << EOLN
        Base64.strict_encode64(data).each_slice(76) do |line|
          f.write line
          f.write EOLN
        end
      end
    end

    def write_file(attachment)
      case attachment
      when String
        if File.file?(attachment)
          write_file_by_path(attachment)
        else
          fail Errno::ENOENT, data
        end
      when File
        write_file_by_path(attachment.path)
      else
        fail ArgumentError
      end
    end

    def write_file_by_path(path)
      mime = `file --mime-type --mime-encoding -b '#{path}'`.strip
      append_message do |f|
        f.write "Content-Type: #{mime}" << EOLN
        f.write "Content-Transfer-Encoding: base64" << EOLN
        f.write "Content-Disposition: attachment; filename=\"#{File.basename(path)}\"" << EOLN << EOLN
      end
      `base64 #{path} >> #{message_path}`
    end

    def append_message
      File.open(message_path, 'a') do |f|
        yield f
      end
    end

    def get_boundary
      Digest::MD5.hexdigest(rand.to_s)[0..7]
    end
  end
end
