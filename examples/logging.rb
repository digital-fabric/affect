require 'bundler/setup'
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