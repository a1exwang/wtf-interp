require_relative '../api'

module Wtf
  module Stdlib
    class Math
      include Wtf::Api::WtfModuleBase
      module_name 'Math'

      defn 'sin' do |_env, x|
        ::Math.sin(x)
      end
    end
  end
end
