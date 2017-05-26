require_relative 'parser'
require_relative 'stdlib/kernel'
module Wtf
  STDLIB_DIR = File.join(File.dirname(__FILE__), 'stdlib', 'wtf')

  def self.wtf_parse_require_path(file_name, current_script_path)
    if file_name =~ /^\./
      # relative
      if current_script_path
        File.join(current_script_path, file_name + '.wtf')
      else
        raise RuntimeError.new("require/import: I don't know current path to require.")
      end
    else
      # stdlib
      File.join(STDLIB_DIR, file_name + '.wtf')
    end
  end
  def self.wtf_eval(str, current_bindings, file_path = 'eval')
    lexer = Wtf::Lexer.new(str, file_path)
    parser = Wtf::Parser.new
    root_node = parser.parse(lexer)
    root_node.set_lexical_parent(current_bindings)
    vm = Wtf::VM.instance
    vm.execute(root_node, current_bindings)
  end
  def self.wtf_require(file_name, current_bindings)
    path = nil
    if current_bindings.entity && current_bindings.entity.file
      path = File.dirname(current_bindings.entity.file)
    end
    file_path = wtf_parse_require_path(file_name, path)
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
    # TODO
    file_path = self.wtf_parse_require_path(file_name, '.')
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
