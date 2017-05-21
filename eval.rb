require_relative 'parser'
require_relative 'stdlib/kernel'
module Wtf
  STDLIB_DIR = File.join(File.dirname(__FILE__), 'stdlib', 'wtf')
  def self.wtf_eval(str, current_bindings)
    lexer = Wtf::Lexer.new(str, 'eval', 1, 1)
    parser = Wtf::Parser.new
    ast = parser.parse(lexer)
    ast.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(ast, current_bindings)
  end
  def self.wtf_require(file_path, current_bindings)
    begin
      str = File.read(File.join(STDLIB_DIR, file_path + '.wtf'))
    rescue Errno::ENOENT
      raise Wtf::Lang::Exception::FileNotFound, "require(\"#{file_path}\" not found"
    end
    lexer = Wtf::Lexer.new(str, file_path)
    ast = Wtf::Parser.new.parse(lexer)
    ast.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(ast, current_bindings)
  end
end
