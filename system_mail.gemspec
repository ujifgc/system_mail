# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'system_mail/version'

Gem::Specification.new do |spec|
  spec.name          = "system_mail"
  spec.version       = SystemMail::VERSION
  spec.authors       = ["Igor Bochkariov"]
  spec.email         = ["ujifgc@gmail.com"]
  spec.description   = 'A Ruby library built to compose and deliver internet mail using operating system utilities.'
  spec.summary       = 'SystemMail is a blazing-fast Ruby Mail alternative with tiny memory footprint.'
  spec.homepage      = "https://github.com/ujifgc/system_mail"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
