require_relative 'lexer'
require_relative 'parser'

lexer = Wtf::Lexer.new
parser = Wtf::Parser.new(lexer)

if ARGV.size == 0
	puts
	puts 'type "Q" to quit.'
	puts
	line = 1
	while true
		puts
		print '? '
		str = gets.chop!
		break if /q/i =~ str
		begin
			lexer.load_file(str, 'iwtf', line, 1)
			puts "= #{parser.parse}"
		rescue ParseError
			puts $!
		end
		line += 1
	end
elsif ARGV.size == 1
	f = File.new(ARGV[0])
	str = f.read
	lexer.load_file(str, f.path, 1, 1)
	puts "= #{parser.parse}"
else
	puts 'wrong argument'
	exit 1
end

