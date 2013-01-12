# A framework for static website generation which regenerates files in place.

require 'regenerate/web-page.rb'
require 'regenerate/site-regenerator.rb'

STDOUT.sync = true
STDERR.sync = true

#puts "ARGV = #{ARGV.inspect}"

if ARGV.length >= 1
  Regenerate.regeneratePath(ARGV[0])
end
