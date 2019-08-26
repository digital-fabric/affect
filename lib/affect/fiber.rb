# frozen_string_literal: true

require 'fiber'

# Affect module
module Affect
  module Fiber
    extend self

    class Intent
      def initialize(*args)
        @args = args
      end

      attr_reader :args
    end

    class Escape < Intent
      def initialize(&block)
        @block = block
      end

      def call(*args)
        @block.(*args)
      end
    end

    def capture(*args, &block)
      block, handler = case args.size
        when 1 then block ? [block, args.first] : [args.first, nil]
        when 2 then args
        else [block, nil]
      end

      f = Fiber.new(&block)
      v = f.resume
      loop do
        break v unless f.alive? && v.is_a?(Intent)

        if v.is_a?(Escape)
          break v.()
        else
          v = f.resume(handler.(*v.args))
        end
      end
    end

    def perform(*args)
      Fiber.yield Intent.new(*args)
    rescue FiberError
      raise RuntimeError, 'perform called outside of capture'
    end

    def escape(value = nil, &block)
      block ||= proc { value }
      Fiber.yield Escape.new(&block)
    rescue FiberError
      raise RuntimeError, 'escape called outside of capture'
    end

    def method_missing(*args)
      perform(*args)
    end

    class Context
      def initialize(handlers = nil, &block)
        @handlers = handlers || { nil => block || -> { } }
      end

      attr_reader :handlers

      def handler_proc
        proc { |effect, *args| handle(effect, *args) }
      end

      def handle(effect, *args)
        handler = find_handler(effect)
        if handler
          call_handler(handler, effect, *args)
        else
          begin
            Fiber.yield Intent.new(effect, *args)
          rescue FiberError
            raise RuntimeError, "No handler found for #{effect.inspect}"
          end
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

      def capture(&block)
        Affect.capture(block, handler_proc)
      end
    end
  end
end

module Kernel
  def Affect(handlers = nil, &block)
    Affect::Context.new(handlers, &block)
  end
end
