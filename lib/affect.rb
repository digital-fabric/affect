module Affect
  class Context
    def initialize(&block)
      @closure = block
      @handlers = {}
    end

    def on(o, &block)
      o.is_a?(Hash) ? @handlers.merge!(o) : (@handlers[o] = block)
      self
    end

    def emit(o, *args)
      # TODO
      if (handler = find_handler(o))
        call_handler(handler, o, *args)
      elsif @parent_context
        @parent_context.emit(o, *args)
      else
        raise "No effect handler for #{o.inspect}"
      end
    end

    def find_handler(o)
      @handlers[o] || @handlers[o.class]
    end

    def call_handler(handler, o, *args)
      if handler.arity == 0
        handler.()
      elsif args.empty?
        handler.(o)
      else
        handler.(*args)
      end
    end

    def call(&block)
      current_thread = Thread.current
      @parent_context = current_thread[:__affect_context__]
      current_thread[:__affect_context__] = self
      (block || @closure).()
    ensure
      current_thread[:__affect_context__] = @parent_context
      @parent_context = nil
    end
  end

  def self.run(&block)
    Context.new(&block)
  end

  def self.call(&block)
    Context.new(&block).()
  end

  def self.on(m, &block)
    Context.new.on(m, &block)
  end

  def self.emit(o, *args)
    current_thread = Thread.current
    current_context = current_thread[:__affect_context__]
    raise "No effect context present" unless current_context

    current_context.emit(o, *args)
  end
end

module ::Kernel
  def Affect(o, *args)
    current_thread = Thread.current
    current_context = current_thread[:__affect_context__]
    raise "No effect context present" unless current_context

    current_context.emit(o, *args)
  end
end