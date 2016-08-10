module Wtf
  module Api
    class WtfModuleBaseHelper
      attr_accessor :mods
      def fuck(vm)
        mods.each do |mod|
          outer = vm.find_var(mod.get_outer_name)
          mod = vm.defm(mod.get_module_name, outer.bindings)
          mod.get_method_list.each do |m|

            # define a method in mod
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

          def module_name(name)

          end

          def defn(name, &block)
            { name: name, fn: block }
          end
        end
      end
    end
  end
end

class StdMath
  include Wtf::Api::WtfModuleBase
  module_name 'Math'

  defn 'sin' do |_env, x|
    Math.sin(x)
  end
end