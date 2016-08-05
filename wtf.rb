require_relative 'lexer'
require_relative 'parser'
require_relative 'vm'
require 'optparse'

args = ARGV
program_args = []
ARGV.each_with_index do |arg, i|
  if arg == '-a'
    args = ARGV[0...i]
    program_args = ARGV[i..-1]
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

end.parse!(args)

if options[:m] == :iwtf
  puts 'interactive wtf'
	line = 1
	while true
		print "\niwtf> "
		str = gets&.chop!
		break unless str
    begin
			lexer.load_file(str, 'iwtf', line, 1)
			puts "= #{parser.parse}"
		rescue ParseError
			puts $!
		end
		line += 1
	end
  exit
end

raise "file not found: #{options[:file_path]}" unless File.exist? options[:file_path]

f = File.new(options[:file_path])
str = f.read

lexer = Wtf::Lexer.new(str, f.path, 1, 1)
parser = Wtf::Parser.new

# Parser
ast = parser.parse(lexer)
if options[:stage] == :ast
  puts JSON.pretty_generate(JSON.parse(ast.to_json))
  exit
end

# AST traversing 1
ast.set_lexical_parent(Wtf::VM.instance.global_bindings)
if options[:stage] == :ast1
  puts JSON.pretty_generate(JSON.parse(ast.to_json))
  exit
end

# Create VM
vm = Wtf::VM.instance
vm.set_program_args(program_args)

# Load stdlib
vm.load_stdlib


vm.execute(ast)
vm.execute_fn('main')

