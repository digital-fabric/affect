# frozen_string_literal: true

# adapted from:
#   https://github.com/mveytsman/DelimR/blob/master/lib/delimr.rb

require 'continuation'

module Affect
  module Cont
    extend self

    # holds objects of the form [bool, Continuation]
    # where bool siginifies a 
    @@stack = []

    def abort(v)
      (@@stack.pop)[1].(v)
    end

    def capture(&block)
      callcc { |outer|
        @@stack << [true, outer]
        abort(block.())
      }
    end

    def escape
      callcc do |esc|
        unwound_continuations = unwind_stack
        cont_proc = lambda { |v|
          callcc do |ret|
            @@stack << [true, ret]
            unwound_continuations.each { |c| @@stack << [nil, c] }
            esc.call(v)
          end
        }
        abort(yield(cont_proc))
      end
    end

    def unwind_stack
    unwound = []
      while @@stack.last && !(@@stack.last)[0]
        unwound << (@@stack.pop)[1]
      end
      unwound.reverse
    end
  end
end