require 'minitest/autorun'
require 'bundler/setup'
require 'affect'

class AffectAPITest < Minitest::Test
  def test_that_emit_raises_on_no_handler
    assert_raises RuntimeError do
      Affect.run {
        Affect.emit :foo
      }.on(:bar) {
        :baz
      }.()
    end

    # no raise
    Affect.run {
      Affect.emit :foo
    }.on(:foo) {
      :bar
    }.()
  end

  def test_that_emitted_effect_is_performed
    counter = 0
    Affect.run {
      3.times { Affect.emit :incr }
    }.on(:incr) {
      counter += 1
    }.()

    assert_equal(3, counter)
  end

  def test_that_api_methods_return_context
    o = Affect.run {
      Affect.emit :foo
    }
    assert_kind_of(Affect::Context, o)

    o = Affect.on(:foo) {
      :bar
    }
    assert_kind_of(Affect::Context, o)
  end
end
