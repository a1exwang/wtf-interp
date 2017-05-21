require_relative '../api'

module Wtf
  module Stdlib
    class Math
      include Wtf::Api::WtfModuleBase
      module_name 'Math'

      defn 'sin' do |_env, x|
        Wtf::Lang::FloatType.new(::Math.sin(x.val))
      end
    end
  end
end
