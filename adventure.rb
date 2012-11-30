adventurer = Object.new

def adventurer.look
  puts location.description
end

class << adventurer
  attr_accessor :location
end

end_of_road = Object.new
def end_of_road.description
<<END
You are standing at the end of a road before a small brick building.
Around you is a forest.  A small stream flows out of the building and
down a gully.
END
end

adventurer.location = end_of_road

adventurer.look

class ObjectBuilder
  def initialize(object)
    @object = object
    @class  = object.singleton_class
  end

  def respond_to_missing?(missing_method, include_private=false)
    missing_method =~ /=\z/
  end

  def method_missing(missing_method, *args, &block)
    if respond_to_missing?(missing_method)
      method_name = missing_method.to_s.sub(/=\z/, '')
      value       = args.first
      ivar_name   = "@#{method_name}"
     if value.is_a?(Proc)
        define_code_method(method_name, ivar_name, value)
      else
        define_value_method(method_name, ivar_name, value)
      end
    else
      super
    end
  end

  def define_value_method(method_name, ivar_name, value)
    @object.instance_variable_set(ivar_name, value)
    @class.class_eval do
      define_method(method_name) do
        instance_variable_get(ivar_name)
      end
    end
  end

  def define_code_method(method_name, ivar_name, implementation)
    @object.instance_variable_set(ivar_name, implementation)
    @class.class_eval do
      define_method(method_name) do |*args|
        instance_exec(*args, &instance_variable_get(ivar_name))
      end
    end
  end
end

def Object(&definition)
  obj = Object.new
  obj.singleton_class.instance_exec(ObjectBuilder.new(obj), &definition)
  obj
end

adventurer = Object { |o|
  o.location = end_of_road
  attr_writer :location

  o.look = ->(*args) {
    puts location.description
  }
}

adventurer.look

def Object(object=nil, &definition)
  obj = object || Object.new
  obj.singleton_class.instance_exec(ObjectBuilder.new(obj), &definition)
  obj
end

Object(adventurer) { |o|
  o.go = ->(direction){
    if(destination = location.exits[direction])
      self.location = destination
      puts location.description
    else
      puts "You can't go that way"
    end
  }
}

wellhouse = Object { |o|
  o.description = <<END
You are inside a small building, a wellhouse for a large spring.
END
}

Object(end_of_road) { |o|
  o.exits = {north: wellhouse}
}

adventurer.go(:north)

room = Object { |o|
  o.exits = {}
}

new_wellhouse = room.clone

new_wellhouse.exits[:south] = end_of_road
new_wellhouse.exits
# => {:south=>
#      #<Object:0x00000002f56ef8
#       @exits=
#        {:north=>
#          #<Object:0x00000002f560e8
#           @description=
#            "You are inside a small building, a wellhouse for a large spring.\n">}>}
room.exits
# => {:south=>
#      #<Object:0x00000002f56ef8
#       @exits=
#        {:north=>
#          #<Object:0x00000002f560e8
#           @description=
#            "You are inside a small building, a wellhouse for a large spring.\n">}>}

def initialize_clone(other)
  instance_variables.each do |ivar_name|
    other.instance_variable_set(
      ivar_name,
      instance_variable_get(ivar_name).dup)
  end
end

room = Object { |o|
  o.exits = {}
}

new_wellhouse = room.clone

new_wellhouse.exits[:south] = end_of_road
new_wellhouse.exits

new_wellhouse.exits
# => {:south=>
#      #<Object:0x00000002f56ef8
#       @exits=
#        {:north=>
#          #<Object:0x00000002f560e8
#           @description=
#            "You are inside a small building, a wellhouse for a large spring.\n">}>}
room.exits
# => {}

class Object
  def implementation_of(method_name)
    if respond_to?(method_name)
      implementation = instance_variable_get("@#{method_name}")
      if implementation.is_a?(Proc)
        implementation
      elsif instance_variable_defined?("@#{method_name}")
        # Assume the method is a reader
        ->{ instance_variable_get("@#{method_name}") }
      else
        method(method_name).to_proc
      end
    end
  end
end

class Prototype < Module
  def initialize(target)
    @target = target
    mod     = self
    super() do
      define_method(:respond_to_missing?) do |missing_method, include_private|
        target.respond_to?(missing_method)
      end

      define_method(:method_missing) do |missing_method, *args, &block|
        if target.respond_to?(missing_method)
          implementation = target.implementation_of(missing_method)
          instance_exec(*args, &implementation)
        else
          super(missing_method, *args, &block)
        end
      end
    end
  end
end

class ObjectBuilder
  def prototype(proto)
    # Leave method implementations on the proto object
    ivars = proto.instance_variables.reject{ |ivar_name|
      proto.respond_to?(ivar_name.to_s[1..-1]) &&
      proto.instance_variable_get(ivar_name).is_a?(Proc)
    }
    ivars.each do |ivar_name|
      unless @object.instance_variable_defined?(ivar_name)
        @object.instance_variable_set(
          ivar_name,
          proto.instance_variable_get(ivar_name).dup)
      end
    end
    @object.extend(Prototype.new(proto))
  end
end

Object(wellhouse) { |o|
  o.prototype room
}

wellhouse.exits                 # => {}

adventurer.go(:north)

container = Object { |o|
  o.items = []
  o.transfer_item = ->(item, recipient) {
    recipient.items << items.delete(item)
  }
}

Object(adventurer) {|o|
  o.prototype container

  o.look = -> {
    puts location.description
    location.items.each do |item|
      puts "There is #{item} here."
    end
  }

  o.take = ->(item_name) {
    item = location.items.detect{|item| item.include?(item_name) }
    if item
      location.transfer_item(item, self)
      puts "You take #{item}."
    else
      puts "You see no #{item_name} here"
    end
  }

  o.drop = ->(item_name) {
    item = items.detect{|item| item.include?(item_name) }
    if item
      transfer_item(item, location)
      puts "You drop #{item}."
    else
      puts "You are not carrying #{item_name}"
    end
  }

  o.inventory = -> {
    items.each do |item|
      puts "You have #{item}"
    end
  }
}

Object(wellhouse) { |o|
  o.prototype container
  o.items = [
    "a shiny brass lamp",
    "some food",
    "a bottle of water"
  ]
  o.exits = {south: end_of_road}
}
Object(end_of_road) { |o|
  o.prototype container
}

adventurer.look
adventurer.take("water")
adventurer.inventory
adventurer.look
adventurer.go(:south)
adventurer.inventory
adventurer.drop("water")
adventurer.look


# >> You are standing at the end of a road before a small brick building.
# >> Around you is a forest.  A small stream flows out of the building and
# >> down a gully.
# >> You are standing at the end of a road before a small brick building.
# >> Around you is a forest.  A small stream flows out of the building and
# >> down a gully.
# >> You are inside a small building, a wellhouse for a large spring.
# >> You can't go that way
# >> You are inside a small building, a wellhouse for a large spring.
# >> There is a shiny brass lamp here.
# >> There is some food here.
# >> There is a bottle of water here.
# >> You take a bottle of water.
# >> You have a bottle of water
# >> You are inside a small building, a wellhouse for a large spring.
# >> There is a shiny brass lamp here.
# >> There is some food here.
# >> You are standing at the end of a road before a small brick building.
# >> Around you is a forest.  A small stream flows out of the building and
# >> down a gully.
# >> You have a bottle of water
# >> You drop a bottle of water.
# >> You are standing at the end of a road before a small brick building.
# >> Around you is a forest.  A small stream flows out of the building and
# >> down a gully.
# >> There is a bottle of water here.
