module Wtf
  module Api
    class WtfModuleBaseHelper
      attr_accessor :mods
      def def_one(vm, mod)
        if mod.outer_name
          outer = vm.global_bindings.wtf_find_var(mod.outer_name, '<native>').bindings
        else
          outer = vm.global_bindings
        end
        # puts "Defining #{mod.module_name} in #{mod.outer_name}"

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
          node.bindings.wtf_def_var(name, Wtf::Lang::FunctionType.new(fn_node))
        end
        mod.vars.each do |name, var|
          node.bindings.wtf_def_var(name, var)
        end
        node
      end
      def def_one_and_add(vm, mod, tmp)
        def_one(vm, mod)
        name = mod.module_name
        deps = tmp[name]
        tmp[name] = :ok
        if deps.is_a?(Array)
          deps.each do |dep_on_me|
            def_one_and_add(vm, dep_on_me, tmp)
          end
        end
      end
      def define_all(vm)
        # TODO: build dep tree
        tmp = Hash.new { Array.new }
        mods.each do |mod|
          dep = mod.outer_name
          if dep.nil? || tmp[dep] == :ok
            def_one_and_add(vm, mod, tmp)
          else
            tmp[dep] += [mod]
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
          @function_list = [
              ['functions',  lambda do |env|
                module_bindings = env[:node].lexical_parent
                names = module_bindings.wtf_local_var_names
                Wtf::Lang::ListType.new(names.val.select do |x|
                  obj = module_bindings.wtf_get_var(x.val, '')
                  obj.is_a?(Wtf::FnDefNode)
                end)
              end],
              ['vars', lambda do |env|
                module_bindings = env[:node].lexical_parent
                module_bindings.wtf_local_var_names
              end]
          ]
          @vars = []

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
          def full_name
            (@outer_name ? @outer_name + '::' : '') + @module_name
          end
          def function_list
            @function_list
          end
          def vars
            @vars
          end

          def defn(name, &block)
            @function_list << [name, block]
          end
          def def_var(name, var)
            @vars << [name, var]
          end
        end
      end
    end
  end
end

