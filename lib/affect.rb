# frozen_string_literal: true

# Affect module
module Affect
  extend self

  # Implements an effects context
  class Context
    def initialize(handlers = nil, &block)
      @handlers = handlers || { nil => block || -> {} }
    end

    attr_reader :handlers

    def handler_proc
      proc { |effect, *args| handle(effect, *args) }
    end

    def perform(effect, *args)
      handler = find_handler(effect)
      if handler
        call_handler(handler, effect, *args)
      elsif @parent
        @parent.perform(effect, *args)
      else
        raise "No handler found for #{effect.inspect}"
      end
    end

    def find_handler(effect)
      @handlers[effect] || @handlers[effect.class] || @handlers[nil]
    end

    def call_handler(handler, effect, *args)
      if handler.arity.zero?
        handler.call
      elsif args.empty?
        handler.call(effect)
      else
        handler.call(*args)
      end
    end

    @@current = nil
    def self.current
      @@current
    end

    def capture
      @parent, @@current = @@current, self
      catch(:escape) { yield }
    ensure
      @@current = @parent
    end

    def escape(value = nil)
      throw :escape, (block_given? ? yield : value)
    end
  end

  def capture(*args, &block)
    block, handlers = block_and_handlers_from_args(*args, &block)
    handlers = { nil => handlers } if handlers.is_a?(Proc)
    Context.new(handlers).capture(&block)
  end

  def block_and_handlers_from_args(*args, &block)
    case args.size
    when 1 then block ? [block, args.first] : [args.first, nil]
    when 2 then args
    else [block, nil]
    end
  end

  def perform(effect, *args)
    unless (ctx = Context.current)
      raise 'perform called outside capture block'
    end

    ctx.perform(effect, *args)
  end

  def escape(value = nil, &block)
    unless (ctx = Context.current)
      raise 'escape called outside capture block'
    end

    ctx.escape(value, &block)
  end

  def respond_to_missing?(*)
    true
  end

  def method_missing(*args)
    perform(*args)
  end
end

# Kernel extensions
module Kernel
  def Affect(handlers = nil, &block)
    Affect::Context.new(handlers, &block)
  end
end
