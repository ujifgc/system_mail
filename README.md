[![Build Status](https://travis-ci.org/ujifgc/system_mail.png)](https://travis-ci.org/ujifgc/system_mail)
[![Code Climate](https://codeclimate.com/github/ujifgc/system_mail.png)](https://codeclimate.com/github/ujifgc/system_mail)

# SystemMail

SystemMail is Ruby library built to compose and deliver internet mail using
operating system utilities.

SystemMail features:

* tiny memory footprint even with big attachments
* blazing-fast gem loading and message composing
* alternating message body format: text, enriched, HTML
* rich capabilities in attaching files
* ability to combine HTML message with file attachments

Operating system commands used to do the job are:

* `sendmail -t < temp` or alternative sends the message to Mail Transfer Agent
* `base64 file >> temp` encodes binary files to textual form
* `file --mime-type --mime-encoding -b file` detects Content-Type and charset

## Installation

Add this line to your application's Gemfile:

    gem 'system_mail'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install system_mail

## Usage

    mail = SystemMail.new(
      from: 'user@example.com',
      to: ['user1@gmail.com', 'user2@gmail.com'],
      subject: 'test проверочный subject',
      files: ['Gemfile', 'Gemfile.lock'],
      text: 'big small норм',
      html: File.read('test.html')
    mail.deliver

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
