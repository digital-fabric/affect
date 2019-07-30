# frozen_string_literal: true

# Affect module
module Affect
  Abort = Object.new # Used as an abort intent

  # Effect context
  class Context
    def initialize(&block)
      @closure = block
      @handlers = {}
    end

    def on(effect, &block)
      if effect.is_a?(Hash)
        @handlers.merge!(effect)
      else
        @handlers[effect] = block
      end
      self
    end

    def handle(&block)
      @handlers[nil] = block
      self
    end

    def perform(effect, *args)
      if (handler = find_handler(effect))
        call_handler(handler, effect, *args)
      elsif @parent_context
        @parent_context.perform(effect, *args)
      else
        raise "No effect handler for #{effect.inspect}"
      end
    end

    def find_handler(effect)
      @handlers[effect] || @handlers[effect.class] || @handlers[nil]
    end

    def call_handler(handler, effect, *args)
      if handler.arity == 0
        handler.call
      elsif args.empty?
        handler.call(effect)
      else
        handler.call(*args)
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
        (block || @closure).call
      end
    ensure
      current_thread[:__affect_context__] = @parent_context
    end
  end

  class << self
    def wrap(&block)
      Context.new(&block)
    end

    def call(&block)
      Context.new(&block).call
    end

    def on(effect, &block)
      Context.new.on(effect, &block)
    end

    def handle(&block)
      Context.new.handle(&block)
    end

    def current_context
      Thread.current[:__affect_context__] || (raise 'No effect context present')
    end

    def perform(effect, *args)
      current_context.perform(effect, *args)
    end

    alias_method :method_missing, :perform

    def abort!(value = nil)
      current_context.abort!(value)
    end
  end
end

# Kernel extension
module Kernel
  def Affect(effect, *args)
    Affect.current_context.perform(effect, *args)
  end
end
