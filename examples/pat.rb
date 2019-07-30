require 'bundler/setup'
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
  gets: -> { STDIN.gets },
  log: ->(msg) { STDERR.puts "#{Time.now} #{msg}" }
).() {
  pattern = /#{ARGV[0]}/
  count = pattern_count(pattern)
  puts count
}