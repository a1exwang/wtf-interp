require_relative 'parser'
require_relative 'stdlib/kernel'
module Wtf
  STDLIB_DIR = File.join(File.dirname(__FILE__), 'stdlib', 'wtf')
  def self.wtf_eval(str, current_bindings, file_path = 'eval')
    lexer = Wtf::Lexer.new(str, file_path)
    parser = Wtf::Parser.new
    ast = parser.parse(lexer)
    ast.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(ast, current_bindings)
  end
  def self.wtf_require(file_name, current_bindings)
    file_path = File.join(STDLIB_DIR, file_name + '.wtf')
    io = open(file_path, 'r')
    self.wtf_load_file(io, file_path, current_bindings)
  end
  def self.wtf_load_file(io, file_path, current_bindings)
    begin
      str = io.read
    rescue Errno::ENOENT
      raise Wtf::Lang::Exception::FileNotFound, "File \"#{file_path}\" not found"
    end
    self.wtf_eval(str, current_bindings, file_path)
  end
end
