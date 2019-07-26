require 'bundler/setup'
require 'affect'

def main
  Affect :prompt
  name = Affect :input
  Affect :output, "Hi, #{name}! I'm Affected Ruby!"
end

ctx = Affect.on(
  prompt: -> { puts "Enter your name: " },
  input:  -> { gets.chomp },
  output: ->(msg) { puts msg }
)

ctx.() { main }