require 'system_mail/version'
require 'system_mail/message'

module SystemMail
  def self.new(options = {}, &block)
    message = Message.new(options)
    message.instance_eval(&block) if block_given?
    message
  end

  def self.email(options = {}, &block)
    message = SystemMail.new(options, &block)
    message.deliver
  end
end

Mail = SystemMail
