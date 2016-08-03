module Wtf
	class Lexer
		def initialize(str = nil, filename = nil, line = nil, col = nil)
			load_file(str, filename, line, col)
		end

		def load_file(str, filename, line, col)
			@str = str
			@filename = filename
			@current_line = line
			@current_col = col
		end

		def next_token
			begin
				if @str.size == 0
					return [false, '$end']
				end
				ret = case @str
							when /\A(\n|\r|\r\n)/
								@current_line += 1
								@current_col = -$&.length + 1
								nil
							when /\A[ \t]+/
								nil
							when /\A>_</
								[:FN_BEGIN, {str: $&, line: @current_line, col: @current_col }]
							when /\A,/
								[:COMMA, {str: $&, line: @current_line, col: @current_col }]
							when /\A-_-!b/
								[:FN_END, {str: $&, line: @current_line, col: @current_col } ]
							when /\A\(/
								[:LPAR, {str: $&, line: @current_line, col: @current_col }]
							when /\A\)/
								[:RPAR, {str: $&, line: @current_line, col: @current_col }]
							when /\A=/
								[:EQ, {str: $&, line: @current_line, col: @current_col }]
							when /\A\+/
								[:PLUS, {str: $&, line: @current_line, col: @current_col }]
							when /\A-/
								[:HYPHEN, {str: $&, line: @current_line, col: @current_col }]
							when /\A\*/
								[:STAR, {str: $&, line: @current_line, col: @current_col }]
							when /\A\//
								[:SLASH, {str: $&, line: @current_line, col: @current_col }]
							when /\A;/
								[:SEMICOLON, {str: $&, line: @current_line, col: @current_col }]
							when /\A[a-z]+/
								[:IDENTIFIER, {str: $&, line: @current_line, col: @current_col }]
							when /\A\d+/
								[:INTEGER, {str: $&, value: $&.to_i, line: @current_line, col: @current_col }]
							else
								raise "unknown token '#{@str}'"
							end
				@current_col += $&.length
				@str = $'
			end until ret
			ret
		end
	end
end

