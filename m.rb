require 'pry'

module M

  class Obj < BasicObject

    def to_s
      __id__
    end

    def initialize(name: :object, parent: nil, vtable: nil, vtable_vtable: nil)
      @name, @methods, @parent, @vtable, @vtable_vtable = name, {}, parent, vtable, vtable_vtable
    end

    def vtable_vtable?
      @vtable_vtable
    end

    def parent
      @parent
    end

    def methods
      @methods
    end

    def vtable
      @vtable
    end

    def parent=(p)
      @parent = p
    end

    def vtable=(v)
      @vtable = v
    end

  end

  def self.allocate(s = nil)
    obj = Obj.new(name: :object, parent: nil, vtable: s)
    obj
  end

  def self.delegated(s = nil)
    child = allocate(s ? s.vtable : nil)
    child.parent = s
    child
  end

  def self.add_method(s, sym, m)
    s.methods[sym] = m
    m
  end

  def self.lookup(s, sym)
    ::STDERR.puts "lookup: #{s}, #{sym}. methods: #{s.methods.keys.join(', ')}."
    m = s.methods[sym] || (s.parent && M.send(s.parent, :lookup, sym)) || nil
    ::STDERR.puts "found: #{sym}"
    m
  end

  def self.send(o, m, *args)
    bound_method = bind(o, m)
    r = bound_method.call(o, *args)
    r
  end

  def self.bind(o, m)
    vt = o.vtable
    bound_method = (m == :lookup && o.vtable_vtable?) ? lookup(vt, m) : send(vt, :lookup, m)
    bound_method
  end

end

# Bootstrap
vtable_vt = M::Obj.new(name: :vtable, vtable_vtable: true)
vtable_vt.vtable = vtable_vt

object_vt = M::Obj.new(name: :object)
object_vt.vtable = vtable_vt
vtable_vt.parent = object_vt

# Adding methods
M.add_method(vtable_vt, :lookup, ->(s, sym) { M.lookup(s, sym) })
M.add_method(vtable_vt, :add_method, ->(s, sym, m) { M.add_method(s, sym, m) })
M.send(vtable_vt, :add_method, :allocate, ->(s) { M.allocate(s) })
M.send(vtable_vt, :add_method, :delegated, ->(s) { M.delegated(s) })
symbol_vt = M.send(object_vt, :delegated)
symbol = M.send(symbol_vt, :allocate)
M.send(symbol_vt, :add_method, :intern, ->(s, arg) { arg.to_sym })

# Lets create a chain of vtables with some methods to demonstrate how lookup works
chain = (0...10).reduce([]) do |acc, i| 
  prev = acc[-1] || object_vt
  cur = M.send(prev, :delegated)
  M.send(cur, :add_method, "m#{i}".to_sym, ->(s) { i })
  acc << cur
  acc
end
chained_object = M.send(chain[-1], :allocate)
require 'pry'; binding.pry
