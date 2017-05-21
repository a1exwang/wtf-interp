require_relative 'lexer'
require_relative 'parser'
require_relative 'vm'
require_relative 'stdlib/kernel'
require 'optparse'
require 'stringio'

args = ARGV
program_args = []
ARGV.each_with_index do |arg, i|
  if arg == '-a'
    args = ARGV[0...i]
    program_args = ARGV[(i+1)..-1]
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby wtf.rb [options]'

  opts.on('-s', '--stage STAGE', 'set stage') do |stage|
    options[:stage] = stage.to_sym
  end

  opts.on('-m', '--mode MODE', 'set mode') do |mode|
    options[:mode] = mode.to_sym
  end

  opts.on('-f', '--file FILE_PATH', 'set file') do |file|
    options[:file_path] = file
  end

  opts.on('-e', '--eval CODE', 'evaluate code') do |code|
    options[:mode] = :eval
    options[:code] = code
  end

end.parse!(args)

if options[:mode] == :iwtf
  path = '<iwtf>'
  io = StringIO.new('main = -> { iwtf(); }')
elsif options[:mode] == :eval
  path = '<eval>'
  io = StringIO.new(options[:code])
else
  raise "file not found: #{options[:file_path]}" unless File.exist? options[:file_path]
  io = open(options[:file_path], 'r')
  path = options[:file_path]
end

begin
  vm = Wtf::VM.instance
  vm.set_program_args(program_args)
  vm.load_stdlib
  vm.load_file(io, path)
  vm.execute_top_fn
rescue Wtf::Lang::Exception::WtfError => e
  STDERR.puts "#{e.class}\n  #{e.message}"
  STDERR.puts "Calling stack:\n"
  Thread.current[:stack].reverse_each do |fn|
    caller = fn
    STDERR.puts "\tcaller at '#{caller.location_str}', calling function: #{caller.name}"
  end
end
