require_relative 'parser'

module Wtf
  def self.eval(str, current_bindings)
    lexer = Wtf::Lexer.new(str, 'eval', 1, 1)
    parser = Wtf::Parser.new
    ast = parser.parse(lexer)
    ast.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(ast, current_bindings)
  end
end
