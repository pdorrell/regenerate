# A framework for static website generation which regenerates files in place.

require 'regenerate/web-page.rb'

module Regenerate
  
  def self.regenerate(fileName)
    WebPage.new(fileName)
  end
  
  def self.regenerateThisDir(globPattern = "*.html")
    puts "Regenerating files in #{Dir.pwd} ..."

    Dir.glob('*.html') do | file |
      puts "HTML file: #{file.inspect}"
      if !file.start_with? "_"
        puts "############################################################"
        puts "File: #{file}"
        Regenerate.regenerate(file)
      end
    end

  end
end

#puts "ARGV = #{ARGV.inspect}"

if ARGV.length >= 1
  Regenerate.regenerate(ARGV[0])
end
