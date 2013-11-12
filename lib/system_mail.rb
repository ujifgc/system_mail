require 'system_mail/version'
require 'system_mail/message'

module SystemMail
  def self.new(options={})
    Message.new(options)
  end

  def self.email(&block)
    mail = Message.new(args)
    mail.instance_eval(&block)
    mail.deliver
  end
end

Mail = SystemMail
