# Affect - structured side effects for functional Ruby

[INSTALL](#installing-affect) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples) |

> Affect | əˈfɛkt | verb [with object] have an effect on; make a difference to.

## What is Polyphony

Affect is a tiny Ruby gem providing a way to isolate and handle side-effects in
functional programs. Affect implements algebraic effects in Ruby, but can also
be used to implement patterns that are orthogonal to object-oriented
programming, such as inversion of control and dependency injection.

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

Affect.run {
  puts "Result: #{ mul(2, 3) }"
}.on(:log) { |message|
  puts "#{Time.now} #{message} (this is a log message)"
}.()
```

In the example above, we replace the call to `LOG.info` with an invocation of a `LogIntent` instance. When the intent is passed to `Affect`, the corresponding
handler is called in order to perform the intent.

In essence, by separating the performance of side effects into effect intents,
and effect handlers, we have separated the what from the how. The `mul` method
is no longer concerned with how to log the message it needs to log. There's no 
hardbaked reference to a `Log` object, and no logging API to follow. Instead,
the *intent* to log a message is passed on to `Affect`, which in turn runs the
correct handler that actually does the logging.

## emitting side effects

Side effects are passed, or "emitted", to Affect, which takes care of
performing them. To emit an effect, use the `Affect` global method:

```ruby
Affect :myeffect
```

Affect also accepts multiple arguments:

```ruby
Affect :log, "my message"
```

Intents can also be represented using classes or structs:

```ruby
LogIntent = Struct.new(:msg)

Affect LogIntent.new("my message")
```

## handling side effects

Side effect handlers can be defined using the `#on` or `#handle` methods:

```ruby

```

## The effect context

Affect defines an effect context which is unique to *each thread or fiber*.
Effect contexts can be thought of as stack frames containing information about
effect handlers. When effects are invoked using method calls on `Affect`, the
call is routed to the current effect context. If the current effect context does
not know how to handle a certain effect, the call will bubble up the stack of
effect contexts until a handler is found. If no handler is found, an error is
raised. In the following example, an A/B test is implemented using contexts.

```ruby
require 'affect'

@ctx_a = Affect::Context.new.on(:foo) { 'bar' }
@ctx_b = Affect::Context.new.on(:foo) { 'baz' }

def process(req)
  req.respond(@template.render(foo: Affect.foo))
end

@counter = 0
def handle_request(req)
  @counter += 1
  ctx = @counter % 2 == 0 ? @ctx_a : @ctx_b
  ctx.() { process(req) }
end
```

## Dependency injection

Affect can also be used for dependency injection. Dependencies can be injected
by providing effect handlers:

```ruby
require 'affect'

Affect.on(:db) {
  @my_db_connection
}.() {
  process_users(Affect.db.query('select * from users'))
}
```

## Testing

One particular benefit of using Affect is the way it facilitates testing. When
mutable state and side-effects are pulled out of methods and into effect
handlers, testing becomes much easier. Nested contexts allow the mocking of
state and side-effects.