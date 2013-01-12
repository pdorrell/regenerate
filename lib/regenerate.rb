# A framework for static website generation which regenerates files in place.

require 'regenerate/web-page.rb'
require 'regenerate/site-regenerator.rb'

STDOUT.sync = true
STDERR.sync = true

module Regenerate
  
  def configureRegenerate(path)
    
  end
  
  def self.regenerate(fileName)
    configureRegenerate(File.dirname(fileName))
    WebPage.new(fileName, PageObject).regenerate
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
  Regenerate.regeneratePath(ARGV[0])
end
