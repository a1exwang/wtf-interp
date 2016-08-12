module Wtf
  module Api
    class WtfModuleBaseHelper
      attr_accessor :mods
      def define_all(vm)
        mods.each do |mod|
          if mod.outer_name
            outer = vm.global_bindings.find_var(mod.outer_name).bindings
          else
            outer = vm.global_bindings
          end

          node = Wtf::ModNode.new([])
          node.set_lexical_parent(outer)
          node.bind_to_var(mod.module_name)
          mod_type = Wtf::Lang::ModuleType.new(node, outer, node.bindings)
          outer.wtf_def_var(mod.module_name, mod_type)
          mod.function_list.each do |name, block|
            # the first argument of +block+ is `env`
            args = Array.new(block.arity - 1) { |i| IdNode.new("p#{i}") }
            fn_node = NativeFnDefNode.new(args, lambda do |env, params|
              unless params.size == args.size
                raise Lang::Exception::WrongArgument,
                      "wrong number of args in function #{env[:node].name}: \n" +
                          "#{params.size} given but #{args.size} needed"
              end
              block.(env, *params)
            end)
            fn_node.set_lexical_parent(node.bindings)
            node.bindings.wtf_def_var(name, fn_node)
          end
        end
      end

      def self.instance
        @the_instance ||= self.new
      end
      private
      def initialize
        @mods = []
      end
    end
    module WtfModuleBase
      def self.included(other_mod)
        other_mod.instance_eval do
          WtfModuleBaseHelper.instance.mods << other_mod
          @function_list = []

          def outer_name(name = nil)
            if name
              @outer_name = name
            else
              @outer_name
            end
          end
          def module_name(name = nil)
            if name
              @module_name = name
            else
              @module_name
            end
          end
          def function_list
            @function_list
          end

          def defn(name, &block)
            @function_list << [name, block]
          end
        end
      end
    end
  end
end

