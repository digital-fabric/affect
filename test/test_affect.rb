require 'minitest/autorun'
require 'bundler/setup'
require 'affect'

class AffectAPITest < Minitest::Test
  def test_that_perform_raises_on_no_handler
    assert_raises RuntimeError do
      Affect.wrap {
        Affect.perform :foo
      }.on(:bar) {
        :baz
      }.()
    end

    # using method call on Affect
    assert_raises RuntimeError do
      Affect.wrap {
        Affect.foo
      }.()
    end

    # no raise
    Affect.wrap {
      Affect.perform :foo
    }.on(:foo) {
      :bar
    }.()
  end

  def test_that_emitted_effect_is_performed
    counter = 0
    Affect.wrap {
      3.times { Affect.perform :incr }
    }.on(:incr) {
      counter += 1
    }.()

    assert_equal(3, counter)
  end

  def test_that_api_methods_return_context
    o = Affect.wrap {
      Affect.perform :foo
    }
    assert_kind_of(Affect::Context, o)

    o = Affect.on(:foo) {
      :bar
    }
    assert_kind_of(Affect::Context, o)

    o = Affect.handle { }
    assert_kind_of(Affect::Context, o)
  end

  def test_that_contexts_can_be_nested
    results = []
    o = Affect.wrap {
      Affect.perform :foo
      Affect.perform :bar

      Affect.wrap {
        Affect.perform :foo
        Affect.perform :bar
      }
      .on(:bar) { results << :baz }
      .()
    }
    .on(:foo) { results << :foo }
    .on(:bar) { results << :bar }
    .()

    assert_equal([:foo, :bar, :foo, :baz], results)
  end

  def test_that_effects_can_be_emitted_as_method_calls_on_Affect
    results = []
    o = Affect.wrap {
      Affect.foo
      Affect.bar

      Affect.wrap {
        Affect.foo
        Affect.bar
      }
      .on(:bar) { results << :baz }
      .()
    }
    .on(:foo) { results << :foo }
    .on(:bar) { results << :bar }
    .()

    assert_equal([:foo, :bar, :foo, :baz], results)
  end

  def test_that_abort_can_be_called_from_wrapped_code
    effects = []
    Affect.handle { |o| effects << o }.() do
      Affect 1
      Affect.abort!
      Affect 2
    end

    assert_equal([1], effects)
  end

  def test_that_abort_causes_call_to_return_optional_value
    o = Affect.() { Affect.abort! }
    assert_equal(Affect::Abort, o)

    o = Affect.() { Affect.abort!(42) }
    assert_equal(42, o)
  end

  class I1; end

  class I2; end

  def test_that_intent_instances_are_handled_correctly
    results = []
    Affect
      .on(I1) { results << :i1 }
      .on(I2) { results << :i2 }
      .() {
        Affect I1.new
        Affect I2.new
    }

    assert_equal([:i1, :i2], results)
  end
end
