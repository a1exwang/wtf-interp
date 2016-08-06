require_relative 'ast/nodes'

module Wtf
  module Api
    ##
    # defu = define unnamed function
    def defu(bindings, &block)
      # the first argument of +block+ is `env`
      args = Array.new(block.arity - 1) { |i| IdNode.new("p#{i}") }
      node = NativeFnDefNode.new(args, lambda do |env, params|
        unless params.size == args.size
          raise Lang::Exception::WrongArgument,
                "wrong number of args in function #{env[:node].name}: \n" +
                    "#{params.size} given but #{args.size} needed"
        end
        block.(env, *params)
      end)
      node.set_lexical_parent(bindings)
      node
    end

    ##
    # defn = define named function
    def defn(name, bindings, &block)
      node = defu(bindings, &block)
      node.bind_to_var(name)
      bindings.wtf_def_var(name, node)
    end

    ##
    # global_bindings
    def global_bindings
      Wtf::VM.instance.global_bindings
    end

  end
end