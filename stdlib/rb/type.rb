require_relative '../api'

module Wtf
  module Stdlib
    class Type
      include Wtf::Api::WtfModuleBase
      module_name 'Type'

      defn 'is_a' do |env, obj, type|
        fn = type.bindings.wtf_get_var('is_mine', '<native>::Type::is_a()')
        fn.node.direct_call(env, [obj])
      end
    end
  end
end
