# A framework for static website generation which regenerates files in place.

require_relative 'web-page.rb'

module Rejenner
  
  def self.rejenerate(fileName)
    WebPage.new(fileName)
  end
end

puts "ARGV = #{ARGV.inspect}"

if ARGV.length >= 1
  Rejenner.rejenerate(ARGV[0])
end
