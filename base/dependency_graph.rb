context :DependencyGraph do

  def initialize(context_name, methods, dependencies)
    @context_name = context_name
    @methods = methods
    @dependencies = dependencies
  end

  role :methods do
    def dependencies
      methods.select{|k,v| v.methods != nil && v.methods.length  >0}.each do |r, role|
        bind :r => :role_name
        role_dependencies = (dependencies[r] ||= {})
        role.methods.each do |name, method_sources|
          bind :method_sources => :method, :role_dependencies => :dependency
          method.get_dependencies
        end
      end
    end
  end

  role :dependencies do end
  role :dependency do
    def add(dependent_role_name,method_name)

      if dependent_role_name && dependent_role_name != role_name
        dependency[dependent_role_name] ||= {}

        unless dependency[dependent_role_name].has_key? method_name
          dependency[dependent_role_name][method_name] = 0
        end
        dependency[dependent_role_name][method_name] += 1
      end
    end
  end
  role :role_name do end
  role :method do
    def body
      args = method.definition.detect { |d| d[0] == :args }
      index = method.definition.index(args) + 1
      if method.definition.length > index+1
        body = method.definition[index..-1]
        body.insert(0, :block)
        body
      else
        method.definition[index]
      end
    end

    def ast
      AbstractSyntaxTree.new(method.body, InterpretationContext.new(methods,{},{},Role.new(role_name,__LINE__,__FILE__),{}))
    end
    def definition
      (method.instance_of? Array) ? method[0] : method
    end
    def get_dependencies
      method.ast.each_production do |production|
        name = nil
        method_name = nil
        case production.type
          when Tokens.rolemethod_call
            data = production.data
            name = data[1]
            name = name.name if name.instance_of? Role
            method_name = data[0]
          when Tokens.role
            name = production.data[0]
          else
        end
        dependency.add(name,method_name) if name != nil
      end
    end
  end

  def create!
    methods.dependencies
    dependencies
  end


end

