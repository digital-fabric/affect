require 'bundler/setup'
require 'affect'

def fact(x)
  Affect :log, "calculating factorial for #{x}"
  (x <= 1) ? 1 : x * fact(x - 1)
end

def main
  Affect :prompt
  x = Affect :input
  result = fact(x)
  Affect :output, "The factorial of result is #{result}"
end

ctx = Affect.on(
  prompt: -> { puts "Enter a number: " },
  input:  -> { gets.chomp.to_i },
  output: ->(msg) { puts msg },
  log:    ->(msg) { puts "#{Time.now} #{msg}" }
)

ctx.() { loop { main } }