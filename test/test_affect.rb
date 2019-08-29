# frozen_string_literal: true

require 'minitest/autorun'
require 'bundler/setup'
require 'affect'

class AffectTest < Minitest::Test
  include Affect

  def test_capture_with_different_arities
    assert_equal :foo, capture { :foo }
    assert_equal :foo, capture(-> { :foo })
    
    assert_equal :bar, capture(-> { perform(:foo) }, ->(e) { e == :foo && :bar })

  end

  def test_escape
    assert_raises(RuntimeError) { escape(:foo) }
    assert_raises(RuntimeError) { escape { :foo } }

    assert_equal :bar, capture { [:foo, escape(:bar)] }
    assert_equal :baz, capture { [:foo, escape { :baz }] }
  end

  def test_effect_handler_dsl
    v = 1
    ctx = Affect(
      get: -> { v },
      set: ->(x) { v = x }
    )

    assert_kind_of Affect::Context, ctx

    final = ctx.capture {
      [
        perform(:get),
        perform(:set, 2),
        perform(:get),
        Affect.get,
        Affect.set(3),
        Affect.get
      ]
    }

    assert_equal [1, 2, 2, 2, 3, 3], final
  end

  def test_context_missing_handler
    assert_raises RuntimeError do
      Affect(foo: -> { :bar }).capture { perform :baz }
    end
  end

  def test_context_wildcard_handler
    ctx = Affect do |e| e + 1; end
    assert_equal 3, ctx.capture { perform(2) }
  end

  def test_context_handler_with_block
    assert_equal :bar, Affect(foo: -> &block { block.() }).capture {
      perform(:foo) { :bar }
    }
  end

  def test_that_contexts_can_be_nested
    results = []

    ctx2 = Affect(bar: -> { results << :baz })
    ctx1 = Affect(
      foo: -> { results << :foo },
      bar: -> { results << :bar }
    )

    ctx1.capture {
      Affect.foo
      Affect.bar

      ctx2.capture {
        Affect.foo
        Affect.bar
      }
    }

    assert_equal([:foo, :bar, :foo, :baz], results)
  end

  def test_that_escape_provides_return_value_of_capture
    assert_equal 42, capture { 2 * escape { 42 } }
  end

  class I1; end
  class I2; end

  def test_that_intent_instances_are_handled_correctly
    results = []
    Affect(
      I1 => -> { results << :i1 },
      I2 => -> { results << :i2 }
    ).capture {
      perform I1.new
      perform I2.new
    }

    assert_equal([:i1, :i2], results)
  end

  # doesn't work with callback-based affect
  def test_that_capture_can_work_across_fibers_with_transfer
    require 'fiber'
    f1 = Fiber.new { |f| escape(:foo) }
    f2 = Fiber.new { f1.transfer(f2) }

    # assert_equal :foo, capture { f2.resume }
  end

  # doesn't work with fiber-based Affect
  def test_that_capture_can_work_across_fibers_with_yield
    f1 = Fiber.new { |f| escape(:foo) }
    f2 = Fiber.new { f1.resume }

    # assert_equal :foo, capture { f2.resume }
  end
end

class ContTest < Minitest::Test
  require 'affect/cont'

  Cont = Affect::Cont

  def test_that_continuation_is_provided_to_escape
    k = Cont.capture { 2 * Cont.escape { |cont| cont } }
    assert_kind_of Proc, k
  end

  def test_that_continuation_completes_the_computation_in_capture
    k = Cont.capture { 2 * Cont.escape { |cont| cont } }
    assert_equal 12, k.(6)
  end

  def test_that_continuation_can_be_called_multiple_times
    k = Cont.capture { 2 * Cont.escape { |cont| cont } }
    assert_equal 4, k.(2)
    assert_equal 6, k.(3)
    assert_equal 8, k.(4)
  end
end