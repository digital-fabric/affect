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

> **Note**: Affect does not pretend to be a *complete, theoretically correct*
> implementation of algebraic effects. Affect concentrates on the idea of 
> [effect contexts](#the-effect-context). It does not deal with continuations,
> asynchrony, or any other concurrency constructs.

## Installing Affect

```bash
$ gem install affect
```

Or add it to your Gemfile, you know the drill.

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
  Affect :log, "called with #{x}, #{y}"
  x * y
end

Affect.wrap {
  puts "Result: #{ mul(2, 3) }"
}.on(:log) { |message|
  puts "#{Time.now} #{message} (this is a log message)"
}.()
```

In the example above, we replace the call to `LOG.info` with an invocation of a
`LogIntent` instance. When the intent is passed to `Affect`, the corresponding
handler is called in order to perform the intent.

In essence, by separating the performance of side effects into effect intents,
and effect handlers, we have separated the what from the how. The `mul` method
is no longer concerned with how to log the message it needs to log. There's no 
hardbaked reference to a `Log` object, and no logging API to follow. Instead,
the *intent* to log a message is passed on to `Affect`, which in turn runs the
correct handler that actually does the logging.

## Performing side effects

Side effects are performed by calling `Affect.perform` or simply `Affect()` with
a specification of the effect to be performed:

```ruby
Affect.perform :foo

# or:
Affect :foo
```

You can also pass along more arguments. Those will in turn be passed to the
effect handler:

```ruby
Affect :log, 'my message'
```

Effects can be represented using any Ruby object, but in a relatively complex
application might be best represented using classes or structs signifying the
*intent* to perform an effect:

```ruby
LogIntent = Struct.new(:msg)

Affect LogIntent.new('my message')
```

When representing effects using symbols, Affect provides a shorthand way to 
perform effects by calling methods directly on the `Affect` module:

```ruby
Affect.log('my message')
```

Finally, effects should be performed inside of an effect context, by invoking
`Affect::Context#call`. Mostly, you'll want to use the callable shorthand 
`.() { ... }`:

```ruby
def add(x, y)
  Affect :log, "adding #{x} and #{y}..."
  x + y
end

Affect.on(:log) { |msg| puts "#{Time.now} #{msg}" }.() {
  result = add(2, 2)
  puts "result: #{result}"
}
```

## handling side effects

Side effect handlers can be defined using the `Affect.on` or `Affect.handle`
methods. `Affect.on` is used to register one or more effect handlers:

```ruby
# register a single effect handler
Affect.on(:log) { |msg| puts "#{Time.now} #{msg}" }

# register multiple effect handlers by passing in a hash
Affect.on(
  log: ->(msg) { puts "#{Time.now} #{msg}" },
  ask: -> { gets.chomp }
)
```

`Affect.handle` is used as a catch-all handler:

```ruby
Affect.handle do |effect, *args|
  case effect
  when :log   then puts "#{Time.now} #{msg}"
  when :ask   then gets.chomp
  end
end
```

Note that when `Affect.handle` is used to handle effects, no error will be
raised for unhandled effects.

## The effect context

Affect defines an effect context which is unique to *each thread or fiber*.
Effect contexts can be thought of as stack frames containing information about
effect handlers. When effects are invoked using method calls on `Affect`, the
call is routed to the most current effect context. If the current effect context
does not know how to handle a certain effect, the call will bubble up the stack
of effect contexts until a handler is found:

```ruby
# First effect context
Affect.on(:log) { |msg| LOG.info(msg) },
).() {
  log("starting")
  # Second effect context
  Affect.on(
    log: ->(*args) { }
  ).() {
    log("this message will not be logged")
  }
  log("stopping")
}
```

## Putting it all together

The Affect API uses method chaining to add effect handlers and finally, execute
the application code. Multiple effect handlers can be chained as follows:

```ruby
Affect
  .on(:ask) { ... }
  .on(:tell) { ... }
  .() do
    ...
  end
```

## Other usages

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

Affect.on(
  gets: -> { Kernel.gets },
  log: -> { |msg| STDERR << "#{Time.now} #{msg}" }
).() {
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

    Affect.on(:gets) { text.gets }.on(:log) { |msg| } # ignore
    .() {
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

## 