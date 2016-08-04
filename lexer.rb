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
        use_regexp = true
				ret = case @str
							when /\A(#.*)?(\n|\r|\r\n)/
								@current_line += 1
								@current_col = -$&.length + 1
								nil
							when /\A[ \t]+/
								nil
							when /\A->\s*\(/
								[:FN_BEGIN_AND_LPAR, {str: $&, line: @current_line, col: @current_col }]
              when /\A->/
                [:FN_BEGIN, { str: $&, line: @current_col, col: @current_col }]
							when /\A,/
								[:COMMA, { str: $&, line: @current_line, col: @current_col }]
							when /\A\{/
								[:LBRAC, { str: $&, line: @current_line, col: @current_col }]
							when /\A}/
								[:RBRAC, { str: $&, line: @current_line, col: @current_col }]
							when /\A\[/
								[:LBRACK, { str: $&, line: @current_line, col: @current_col }]
							when /\A\]/
								[:RBRACK, { str: $&, line: @current_line, col: @current_col }]
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
							when /\A\./
								[:DOT, { str: $&, line: @current_line, col: @current_col }]
							when /\Aif/
								[:IF, { str: $&, line: @current_line, col: @current_col }]
							when /\Aelse/
								[:ELSE, { str: $&, line: @current_line, col: @current_col }]
							when /\A[_a-zA-Z][_a-zA-Z0-9]*/
								[:IDENTIFIER, {str: $&, line: @current_line, col: @current_col }]
							when /\A\d+/
								[:INTEGER, {str: $&, value: $&.to_i, line: @current_line, col: @current_col }]
              else
                this_str, rest = parse_str_literal(@str, "#{@current_line}, #{@current_col}")
                if this_str
                  val = [:STRING, {str: rest, value: this_str, line: @current_line, col: @current_col}]
                else
                  raise "unknown token '#{@str}'"
                end

                @current_col += this_str.length
                @str = rest
                use_regexp = false

                val
              end
        if use_regexp
          @current_col += $&.length
          @str = $'
        end
			end until ret
			ret
    end

    private
    def parse_str_literal(str, location_str)
      if str[0] != '"'
        return nil
      end
      str = str[1...str.size]
      status = nil
      result = ''
      i = 0
      str.each_char do |c|
        if status == :escape
          result += ESCAPES[c.to_sym]
          status = nil
        else
          if c == '\\'
            status = :escape
            i += 1
            next
          elsif c == '"'
            return result, str[(i+1)...str.size]
          end
          result += c
        end
        i += 1
      end

      raise "invalid string literal at #{location_str}"
    end
    ESCAPES = {
        t: "\t",
        n: "\n",
        '\\': "\\",
        '"': '"'
    }
	end
end

