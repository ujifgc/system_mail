require 'base64'
require 'shellwords'
require 'system_mail/storage'

module SystemMail
  ##
  # Manages compiling an email message from various attributes and files.
  #
  class Message
    BASE64_SIZE = 76
    UTF8_SIZE = 998
    SETTINGS = {
      :sendmail => '/usr/sbin/sendmail -t',
      :base64 => 'base64',
      :file => 'file --mime-type --mime-encoding -b',
      :storage => ENV['TMP'] || '/tmp',
    }.freeze

    ##
    # Creates new message. Available options:
    #
    # - :text, String, Textual part of the message
    # - :enriched, String, Enriched alternative of the message (RFC 1896)
    # - :html, String, HTML alternative of the message
    # - :from, String, 'From:' header for the message
    # - :to, String or Array of Strings, 'To:' header, if Arrey, it gets joined by ', '
    # - :subject, String, Subject of the message, it gets encoded automatically
    # - :files, File or String of file path or Array of them, Attachments of the message
    #
    # Options :text, :enriched and :html are interchangeable.
    # Option :to is required.
    #
    # Examples:
    #
    #   mail = Message.new(
    #     :from        => 'user@example.com',
    #     :to          => 'user@gmail.com',
    #     :subject     => 'test subject',
    #     :text        => 'big small normal',
    #     :html        => File.read('test.html'),
    #     :attachments => [File.open('Gemfile'), 'attachment.zip'],
    #   )
    #
    def initialize(options={})
      @body = {}
      @to = []
      @mutex = Mutex.new
      %W(text enriched html from to subject attachments).each do |option|
        name = option.to_sym
        send(name, options[name])
      end
    end

    ##
    # Delivers the message using sendmail.
    #
    # Example:
    #
    #   mail.deliver #=> nil
    #
    def deliver
      validate
      with_storage do
        write_headers
        write_message
        send_message
      end
    end

    def settings
      @settings ||= SETTINGS.dup
    end

    private

    def text(input)
      @body['text'] = input
    end

    def enriched(input)
      @body['enriched'] = input
    end

    def html(input)
      @body['html'] = input
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

    def attachments(input)
      input && input.each{ |file| add_file(*file) }
    end

    def add_file(name, path = nil)
      path ||= name
      name = File.basename(name)
      files[name] = path
    end

    def files
      @files ||= {}
    end

    def with_storage
      @mutex.synchronize do
        @storage = Storage.new settings[:storage]
        yield
        @storage.clear
        @storage = nil
      end
    end

    def write_message
      if files.any?
        multipart :mixed do |boundary|
          write_part boundary
          write_body
          files.each_pair do |name, path|
            write_part boundary
            write_file name, path
          end
        end
      else
        write_body
      end
    end

    def write_body
      case @body.length
      when 0
        nil
      when 1
        data, type = @body.first
        write_content data, "text/#{type}"
      else
        multipart :alternative do |boundary|
          %w[text enriched html].each do |type|
            data = @body[type] || next
            write_part boundary
            write_content data, "text/#{type}"
          end
        end
      end
    end

    def write_content(data, content_type)
      if data.bytesize < UTF8_SIZE || !data.lines.any?{ |line| line.bytesize > UTF8_SIZE }
        write_8bit_data data, content_type
      else
        write_base64_data data, content_type
      end
    end

    def multipart(type)
      boundary = new_boundary(type)
      @storage.puts "Content-Type: multipart/#{type}; boundary=\"#{boundary}\""
      yield boundary
      write_part boundary, :end
    end

    def write_headers
      @storage.puts "From: #{encode_from}"  if @from
      @storage.puts "To: #{encode_to}"
      @storage.puts "Subject: #{encode_subject}"
    end

    def write_part(boundary, type = :begin)
      @storage.puts
      @storage.puts "--#{boundary}#{type == :end ? '--' : ''}"
    end

    def write_base64_data(data, content_type)
      @storage.puts "Content-Type: #{content_type}; charset=#{data.encoding}"
      @storage.puts "Content-Transfer-Encoding: base64"
      @storage.puts
      Base64.strict_encode64(data).scan(/.{1,#{BASE64_SIZE}/).each do |line|
        @storage.puts line
      end
    end

    def write_8bit_data(data, content_type)
      @storage.puts "Content-Type: #{content_type}; charset=#{data.encoding}"
      @storage.puts "Content-Transfer-Encoding: 8bit"
      @storage.puts
      @storage.puts data
    end

    def write_file(name, file)
      path = case file
      when String
        fail Errno::ENOENT, file  unless File.file?(file)
        fail Errno::EACCES, file  unless File.readable?(file)
        file
      when File
        file.path
      else
        fail ArgumentError, 'attachment must be File or String of file path'
      end
      write_base64_file name, path
    end

    def write_base64_file(name, path)
      @storage.puts "Content-Type: #{read_mime(path)}"
      @storage.puts "Content-Transfer-Encoding: base64"
      @storage.puts "Content-Disposition: attachment; filename=\"#{name}\""
      @storage.puts
      @storage.capture do |message_path|
        `#{settings[:base64]} '#{path.shellescape}' >> #{message_path}`
      end
    end

    def send_message
      if @storage.file?
        @storage.capture do |message_path|
          `#{settings[:sendmail]} < #{message_path}`
        end
      else
        IO.popen(settings[:sendmail], 'w') do |io|
          io.puts @storage.read
        end
      end
    end

    def read_mime(file_path)
      `#{settings[:file]} '#{file_path.shellescape}'`.strip
    end

    def validate
      fail ArgumentError, "Header 'To:' is empty" if @to.empty?
      warn 'Message body is empty' if @body.empty?
    end

    def new_boundary(type)
      rand(36**6).to_s(36).rjust(20,type.to_s)
    end

    def encode_subject
      @subject.ascii_only? ? @subject : encode_utf8(@subject)
    end

    def encode_from
      encode_address(@from)
    end

    def encode_to
      @to.map do |to|
        encode_address(to)
      end.join(', ')
    end

    def encode_address(address)
      if address.ascii_only?
        address
      else
        if matchdata = address.match(/(.+)\s\<(.+)\>/)
          "#{encode_utf8 matchdata[1]} <#{matchdata[2]}>"
        else
          address
        end
      end
    end

    def encode_utf8(input)
      "=?UTF-8?B?#{Base64.strict_encode64 input}?="
    end
  end
end
