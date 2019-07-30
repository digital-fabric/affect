module Affect
  Abort = Object.new # Used as an abort intent

  class Context
    def initialize(&block)
      @closure = block
      @handlers = {}
    end

    def on(o, &block)
      o.is_a?(Hash) ? @handlers.merge!(o) : (@handlers[o] = block)
      self
    end

    def handle(&block)
      @handlers[nil] = block
      self
    end

    def perform(o, *args)
      if (handler = find_handler(o))
        call_handler(handler, o, *args)
      elsif @parent_context
        @parent_context.perform(o, *args)
      else
        raise "No effect handler for #{o.inspect}"
      end
    end

    def find_handler(o)
      @handlers[o] || @handlers[o.class] || @handlers[nil]
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

    def abort!(value = nil)
      throw Abort, (value || Abort)
    end

    def call(&block)
      current_thread = Thread.current
      @parent_context = current_thread[:__affect_context__]
      current_thread[:__affect_context__] = self
      catch(Abort) do
        (block || @closure).()
      end
    ensure
      current_thread[:__affect_context__] = @parent_context
    end
  end

  def self.wrap(&block)
    Context.new(&block)
  end

  def self.call(&block)
    Context.new(&block).()
  end

  def self.on(m, &block)
    Context.new.on(m, &block)
  end

  def self.handle(&block)
    Context.new.handle(&block)
  end

  def self.current_context
    Thread.current[:__affect_context__] || (raise 'No effect context present')
  end

  def self.perform(o, *args)
    current_context.perform(o, *args)
  end

  def self.method_missing(m, *args)
    perform(m, *args)
  end

  def self.abort!(value = nil)
    current_context.abort!(value)
  end
end

module ::Kernel
  def Affect(o, *args)
    Affect.current_context.perform(o, *args)
  end
end