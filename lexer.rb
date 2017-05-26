module Wtf
	class Lexer
		def initialize(str = nil, filename = nil, line = 1, col = 1)
			load_file(str, filename, line, col)
		end

		def load_file(str, filename, line, col)
			@str = str
			@filename = filename
			@current_line = line
			@current_col = col
    end

		def cur_loc(str)
			{ str: str, file: @filename, line: @current_line, col: @current_col }
		end

		def next_token
			begin
				if @str.nil? or @str.size == 0
					return [false, '$end']
				end
        use_regexp = true
				is_new_line = false
				ret = case @str
							when /\A(#.*)?(\n|\r|\r\n)/
								@current_line += 1
								@current_col = 1
								is_new_line = true
								nil
							when /\A[ \t]+/
								nil
							when /\A->\s*\(/
								:FN_BEGIN_AND_LPAR
              when /\A->/
                :FN_BEGIN
							when /\A>=/
								:GTE
							when /\A<=/
								:LTE
							when /\A==/
								:EQEQ
							when /\A!=/
								:NEQ
							when /\A</
								:LT
							when /\A>/
								:GT
							when /\A::/
								:COLON2
							when /\A,/
								:COMMA
							when /\A\{/
								:LBRAC
							when /\A}/
								:RBRAC
							when /\A\[/
								:LBRACK
							when /\A\]/
								:RBRACK
							when /\A\(/
								:LPAR
							when /\A\)/
								:RPAR
							when /\A=/
								:EQ
							when /\A\+/
								:PLUS
							when /\A-/
								:HYPHEN
							when /\A\*/
								:STAR
							when /\A\//
								:SLASH
							when /\A;/
								:SEMICOLON
							when /\A\./
								:DOT
							when /\A:/
								:COLON
							when /\Aif\b/
								:IF
							when /\Aelse\b/
								:ELSE
							when /\Amodule\b/
								:MODULE
							when /\Alet\b/
								:LET
              when /\Asecure\b/
                :EXCEPTION_BEGIN
							when /\Arescue\b/
								:EXCEPTION_RESCUE
							when /\A[_a-zA-Z][_a-zA-Z0-9]*/
								:IDENTIFIER
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
				if ret.is_a?(Symbol)
					ret = [ret, cur_loc($&)]
				end
        if use_regexp
          @current_col += $&.length unless is_new_line
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

