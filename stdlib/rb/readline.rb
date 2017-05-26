require_relative '../api'
require 'readline'

module Wtf
  module Stdlib
    class Readline
      include Wtf::Api::WtfModuleBase
      module_name 'Readline'

      defn 'readline' do |_env, prompt|
        Wtf::Lang::StringType.new(::Readline.readline(prompt.val, true))
      end

    end
  end
end
