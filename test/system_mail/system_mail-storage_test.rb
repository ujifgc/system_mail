require 'minitest_helper'

describe SystemMail::Storage do
  before do
    SystemMail::Storage.class_eval{ attr_accessor :io }
    @fixture_path = File.expand_path('../fixtures/test.html', File.dirname(__FILE__))
    @fixture = File.read @fixture_path
    @s = SystemMail::Storage.new
  end

  after do
    @s.clear
  end

  it 'should properly initialize' do
    assert_kind_of StringIO, @s.io
  end

  it 'should properly write strings' do
    2.times do
      @s.write do |io|
        io.puts 'line1'
        io.puts 'а также линия'
        io.puts
      end
    end
    assert_equal "line1\nа также линия\n\n"*2, @s.io.string
    assert_kind_of StringIO, @s.io
  end

  it 'should properly write and append files with commandline' do
    2.times do
      @s.capture do |path|
        `cat '#{@fixture_path}' >> '#{path}'`
      end
    end
    assert_equal @fixture*2, File.read(@s.io.path)
    assert_kind_of Tempfile, @s.io
    assert_match /system_mail(.*)storage/, @s.io.path
  end

  it 'should properly mix strings and files' do
    2.times do
      @s.write do |io|
        io.puts 'line1'
        io.puts 'а также линия'
        io.puts
      end
      @s.capture do |path|
        File.open(path, 'a') { |f| f.write @fixture }
      end
    end
    assert_equal ("line1\nа также линия\n\n"+@fixture)*2, File.read(@s.io.path)
    assert_kind_of Tempfile, @s.io
  end
end
