# A framework for static website generation which regenerates files in place.

module Rejenner
  
  class Rejenner
    def initialize(fileName)
      @fileName = fileName
    end
    
    def rejenerate
      puts "Opening #{@fileName} ..."
      File.open(@fileName).each_line do |line|
        puts "line: #{line}"
      end
    end
  end
  
  def self.rejenerate(fileName)
    Rejenner.new(fileName).rejenerate
  end
end

if ARGV.length > 0
  Rejenner.rejenerate(ARGV[0])
end
