# Affect - algebraic effects for Ruby

[INSTALL](#installing-affect) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples) |

> Affect | əˈfɛkt | verb [with object] have an effect on; make a difference to.

## What is Affect

Affect is a tiny Ruby gem providing a way to isolate and handle side-effects in
functional programs. Affect implements algebraic effects in Ruby, but can also
be used to implement patterns that are orthogonal to object-oriented
programming, such as inversion of control and dependency injection.

In addition, Affect includes an alternative implementation of algebraic effects
using Ruby fibers, as well as an implementation of delimited continuations using
`callcc` (currently deprecated).

> **Note**: Affect does not pretend to be a *complete, theoretically correct*
> implementation of algebraic effects. Affect concentrates on the idea of 
> [effect contexts](#the-effect-context). It does not deal with continuations,
> asynchrony, or any other concurrency constructs.

## Installing Affect

```ruby
# In your Gemfile
gem 'affect'
```

Or install it manually, you know the drill.

## Getting Started

Algebraic effects introduces the concept of effect handlers, little pieces of
code that are provided by the caller, and invoked by the callee using a uniform
interface. An example of algebraic effects might be logging. Normally, if we
wanted to log a certain message to `STDOUT` or to a file, we wold do the
following:

```ruby
def mul(x, y)
  # assume LOG is a global logger object
  LOG.info("called with #{x}, #{y}")
  x * y
end

puts "Result: #{ mul(2, 3) }"
```

The act of logging is a side-effect of our computation. We need to have a global
`LOG` object, and we cannot test the functioning of the `mul` method in
isolation. What if we wanted to be able to plug-in a custom logger, or intercept
calls to the logger?

Affect provides a solution for such problems by implementing a uniform, 
composable interface for isolating and handling side effects:

```ruby
require 'affect'

def mul(x, y)
  # assume LOG is a global logger object
  Affect.perform :log, "called with #{x}, #{y}"
  x * y
end

Affect.capture(
  log: { |message| puts "#{Time.now} #{message} (this is a log message)" }
) {
  puts "Result: #{ mul(2, 3) }"
```

In the example above, we replace the call to `LOG.info` with the performance of
an *intent* to log a message. When the intent is passed to `Affect`, the
corresponding handler is called in order to perform the effect.

In essence, by separating the performance of side effects into effect intents,
and effect handlers, we have separated the what from the how. The `mul` method
is no longer concerned with how to log the message it needs to log. There's no 
hardbaked reference to a `LOG` object, and no logging API to follow. Instead,
the *intent* to log a message is passed on to Affect, which in turn runs the
correct handler that actually does the logging.

## The effect context

In Affect, effects are performed and handled using an *effect context*. The 
effect context has one or more effect handlers, and is then used to run code
that performs effects, handling effect intents by routing them to the correct
handler.

Effect contexts are defined using either `Affect()` or the shorthand
`Affect.capture`:

```ruby
ctx = Affect(log: -> msg { log_msg(msg) })
ctx.capture { do_something }

# or
Affect.capture(log: -> msg { log_msg(msg) }) { do_something }
```

The `Affect.capture` method can be called in different manners:

```ruby
Affect.capture(handler_hash) { body }
Affect.capture(handler_proc) { body }
Affect.capture(body, handler_hash)
Affect.capture(body, handler_proc)
```

... where `body` is the code to be executed, `handler_hash` is a hash of effect
handling procs, and `handler_proc` is a default effect handling proc.

### Nested effect contexts

Effect contexts can be nested. When an effect context does not know how to
handle a certain effect intent, it passes it on to the parent effect context.
If no handler has been found for the effect intent, an error is raised:

```ruby
# First effect context
Affect.capture(log: ->(msg) { LOG.info(msg) }) {
  Affect.perform :log, 'starting'
  # Second effect context
  Affect.capture(log: ->(msg) { }) {
    Affect.perform :log, 'this message will not be logged'
  }
  Affect.perform :log, 'stopping'

  Affect.perform :foo # raises an error, as no handler is given for :foo
}
```


## Effect handlers

Effect handlers map different effects to a proc or a callable object. When an
effect is performed, Affect will try to find the relevant effect handler by
looking at its *signature* (given as the first argument), and then matching
first by value, then by class. Thus, the effect signature can be either a value,
or a class (normally used when creating intent classes).

The simplest, most idiomatic way to define effect handlers is to use symbols as
effect signatures:

```ruby
Affect(log: -> msg { ... }, ask: -> { ... })
```

A catch-all handler can be defined by calling `Affect()` with a block:

```ruby
Affect do |eff, *args|
  case eff
  when :log
    ...
  when :ask
    ...
  end
end
```

Note that when using a catch-all handler, no error will be raised for unhandled
effects.

## Performing side effects

Side effects are performed by calling `Affect.perform` or simply
`Affect.<intent>` along with one or more parameters:

```ruby
Affect.perform :foo

# or:
Affect.foo
```

Any parameters will be passed along to the effect handler:

```ruby
Affect.perform :log, 'my message'
```

Effects intents can be represented using any Ruby object, but in a relatively
complex application might best be represented using classes or structs:

```ruby
LogIntent = Struct.new(:msg)

Affect.perform LogIntent.new('my message')
```

When using symbols as effect signatures, Affect provides a shorthand way to 
perform effects by calling methods directly on the `Affect` module:

```ruby
Affect.log('my message')
```

## Other uses

In addition to isolating side-effects, Affect can be used for other purposes:

### Dependency injection

Affect can also be used for dependency injection. Dependencies can be injected
by providing effect handlers:

```ruby
Affect.on(:db) {
  get_db_connection
}.() {
  process_users(Affect.db.query('select * from users'))
}
```

This is especially useful for testing purposes as described below:

### Testing

One particular benefit of using Affect is the way it facilitates testing. When
mutable state and side-effects are pulled out of methods and into effect
handlers, testing becomes much easier. Side effects can be mocked or tested
in isolation, and dependencies provided through effect handlers can also be
mocked. The following section includes an example of testing with algebraic
effects.

## Writing applications using algebraic effects

Algebraic effects have yet to be adopted by any widely used programming
language, and they remain a largely theoretical subject in computer science.
Their advantages are still to be proven in actual usage. We might discover that
they're completely inadequate as a solution for managing side-effects, or we
might discover new techniques to be used in conjunction with algebraic effects.

One important principle to keep in mind is that in order to make the best of
algebraic effects, effect handlers need to be pushed to the outside of your
code. In most cases, the effect context will be defined in the entry-point of
your program, rather than somewhere on the inside.

Imagine a program that counts the occurences of a user-defined pattern in a
given text file:

```ruby
require 'affect'

def pattern_count(pattern)
  total_count = 0
  found_count = 0
  while (line = Affect.gets)
    total_count += 1
    found_count += 1 if line =~ pattern
  end
  Affect.log "found #{found_count} occurrences in #{total_count} lines"
  found_count
end

Affect(
  gets: -> { Kernel.gets },
  log: -> { |msg| STDERR << "#{Time.now} #{msg}" }
).capture {
  pattern = /#{ARGV[0]}/
  count = pattern_count(pattern)
  puts count
}
```

In the above example, the `pattern_count` method, which does the "hard work",
communicates with the outside world through Affect in order to:

- read a line after line from some input stream
- log an informational message

Note that `pattern_count` does *not* deal directly with I/O. It does so
exclusively through Affect. Testing the method would be much simpler:

```ruby
require 'minitest'
require 'affect'

class PatternCountTest < Minitest::Test
  def test_correct_count
    text = StringIO.new("foo\nbar")

    Affect(
      gets: -> { text.gets },
      log:  -> |msg| {} # ignore
    .capture {
      count = pattern_count(/foo/)
      assert_equal(1, count)
    }
  end
end
```

## Contributing

Affect is a very small library designed to do very little. If you find it
compelling, have encountered any problems using it, or have any suggestions for
improvements, please feel free to contribute issues or pull requests.