require_relative 'ast/nodes'

module Wtf
  class VM
    def initialize
      @id_list = {
          'puts' => NativeFnDefNode.new([IdNode.new('str')],  lambda do |params|
              raise "wrong number of args: #{params.size}" unless params.size == 1
              puts params.first
            end
          )
      }
    end

    def fn_call(node)
      params = []
      node.params.each do |p|
        params << execute(p)
      end

      fn_node = get_var(node.identifier.name)
      ret = nil
      if fn_node.native?
        fn_node.call(params)
      else
        # params not used
        fn_node.body.each do |code|
          ret = execute(code)
        end
        ret
      end
    end

    def get_var(var)
      if @id_list.key? var.to_s
        @id_list[var]
      else
        raise "var not found: #{var}"
      end
    end

    def execute_fn(name)
      execute(FnCallNode.new(IdNode.new(name), []))
    end

    def execute(node)
      case node
      when IdNode
        return node
      when IntNode
        return node.int_value
      when AssignNode
        name = node.identifier.name
        raise "at #{node.location_str}, duplicate identifier defination: #{name}" if @id_list.key? name
        @id_list[node.identifier.name] = node.exp
        return node.exp 
      when FnDefNode
        return node
      when FnCallNode
        return fn_call(node)
      when Op1Node
        case node.op
        when :plus
          return self.execute(node.p1)
        when :minus
          return -self.execute(node.p1)
        else
          raise 'unknown op1: ' + node.op
        end
      when Op2Node
        p1 = self.execute(node.p1)
        p2 = self.execute(node.p2)

        case node.op
        when :plus
          return p1 + p2
        when :minus
          return p1 - p2
        when :mul
          return p1 * p2
        when :div
          return p1 / p2
        else
          raise 'unknown operator: ' + node.op
        end
      else
        puts node
        raise 'unknown node'
      end
    end
  end

end
