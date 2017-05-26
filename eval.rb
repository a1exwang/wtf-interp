require_relative 'parser'
require_relative 'stdlib/kernel'
module Wtf
  STDLIB_DIR = File.join(File.dirname(__FILE__), 'stdlib', 'wtf')
  def self.wtf_eval(str, current_bindings, file_path = 'eval')
    lexer = Wtf::Lexer.new(str, file_path)
    parser = Wtf::Parser.new
    root_node = parser.parse(lexer)
    root_node.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(root_node, current_bindings)
  end
  def self.wtf_require(file_name, current_bindings)
    file_path = File.join(STDLIB_DIR, file_name + '.wtf')
    io = open(file_path, 'r')
    self.wtf_require_file(io, file_path, current_bindings)
  end
  def self.wtf_require_file(io, file_path, current_bindings)
    begin
      str = io.read
    rescue Errno::ENOENT
      raise Wtf::Lang::Exception::FileNotFound, "File \"#{file_path}\" not found"
    end
    self.wtf_eval(str, current_bindings, file_path)
  end
  def self.wtf_import_str(str, current_bindings, file_path = 'import')
    lexer = Wtf::Lexer.new(str, file_path)
    parser = Wtf::Parser.new
    stmt_list = parser.parse(lexer)
    mod = ModNode.new(stmt_list.stmt_list, file: file_path, l: 0, c: 0)
    mod.set_lexical_parent(current_bindings)
    stmt_list.set_lexical_parent(mod.bindings)
    vm = Wtf::VM.instance
    vm.execute(mod, current_bindings)
  end
  def self.wtf_import(file_name, current_bindings)
    file_path = File.join(STDLIB_DIR, file_name + '.wtf')
    io = open(file_path, 'r')
    self.wtf_import_file(io, file_path, current_bindings)
  end
  def self.wtf_import_file(io, file_path, current_bindings)
    begin
      str = io.read
    rescue Errno::ENOENT
      raise Wtf::Lang::Exception::FileNotFound, "File \"#{file_path}\" not found"
    end
    self.wtf_import_str(str, current_bindings, file_path)
  end
end
