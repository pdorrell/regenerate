# A framework for static website generation which regenerates files in place.

require 'regenerate/web-page.rb'

module Regenerate
  
  def self.regenerate(fileName)
    WebPage.new(fileName)
  end
end

#puts "ARGV = #{ARGV.inspect}"

if ARGV.length >= 1
  Regenerate.regenerate(ARGV[0])
end
