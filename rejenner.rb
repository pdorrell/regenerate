# A framework for static website generation which regenerates files in place.

module Rejenner
  
  class ParseException<Exception
  end
  
  class NonCommandLines
    def initialize
      @lines = []
    end
    
    def addLine(line)
      @lines << line
    end
    
    def forceClose
      # do nothing, OK to force it to close
    end
    
  end
  
  class Rejenner
    
    def initialize(fileName)
      @fileName = fileName
      @commandObjects = []
      @activeObject = nil
      @activeInputObject = nil
      @activeInputCommandName = nil
    end
    
    def forceCloseExistingActiveObject
      if @activeObject
        @activeObject.forceClose
        @activeObject = nil
      end
    end
    
    def startCommandWithName(name)
      forceCloseExistingActiveObject
      commandClass = RejennerCommand.getCommandClass(command)
      @currentInputObject = commandClass.new()
      startCommandObject(@currentInputObject)
      @activeInputCommandName = name
    end
    
    def processInputFromCommentCommand(command, rest)
      startCommandWithName(command)
    end
    
    def processSimpleCommand(command, rest)
      startCommandWithName(command)
      if not @currentInputObject.readsLines
        @activeObject = nil
      end
    end
    
    def processCommentMatch(hashes, isEnd, command, rest)
      puts "# COMMENT match: #{hashes.inspect}, #{isEnd.inspect}, #{command.inspect}, #{rest.inspect}"
      case hashes
      when "#" 
        if isEnd
          processEndInputCommand(command, rest)
        elsif rest =~ /-->$/
          processSimpleCommand(command, rest)
        else
          processInputFromCommentCommand(command, rest)
        end
      when "##"
        if isEnd
          processEndOutputCommand(command, rest)
        else
          processOutputFromCommentCommand(command, rest)
        end
      else
        raiseParseException("More than 2 # characters")
      end
    end
    
    def processEndCommentMatch
      puts "# COMMENT end"
      if @activeObject
        @activeObject.closeActiveCommentInput
        @activeObject = nil
      else
        raise ParseException("End comment for input region found, but no input is active")
      end
    end
    
    def startCommandObject(commandObject)
      @activeObject = commandObject
      @commandObjects << commandObject
    end
    
    def processNonCommandLine(line)
      puts "# LINE: #{line}"
      if @activeObject == nil
        @activeInputObject = nil
        @activeInputCommandName = nil
        startCommandObject(NonCommandLines.new())
      end
      @activeObject.addLine(line)
    end
    
    def parseLine(line)
      rejennerCommentMatch = /^<!--\s*(#+)(end\s+|)\s*(\w*)\s*(.*)$/.match(line)
      if rejennerCommentMatch
        hashes = rejennerCommentMatch[1]
        endString = rejennerCommentMatch[2]
        command = rejennerCommentMatch[3].downcase
        rest = rejennerCommentMatch[4].rstrip
        processCommentMatch(hashes, endString == "end", command, rest)
      else
        endRejennerCommentMatch = /^#\s*-->\s*$/.match(line)
        if endRejennerCommentMatch
          processEndCommentMatch
        else
          processNonCommandLine(line)
        end
      end
    end
    
    def raiseParseException(message)
      puts "#{@fileName}:#{@lineNumber}: #{@currentLine}"
      puts "ERROR: #{message}"
      raise ParseException.new(message)
    end
    
    def rejenerate
      puts "Opening #{@fileName} ..."
      @lineNumber = 0
      @parseState = :html
      File.open(@fileName).each_line do |line|
        @lineNumber += 1
        @currentLine = line
        puts "line #{@lineNumber}: #{line}"
        parseLine(line)
      end
      case @parseState
        when :input
        raiseParseException("At end of file - still in input region")
        when :output
        raiseParseException("At end of file - still in output region")
      end
    end
  end
  
  class RejennerCommand
    @@commandClasses = {}
    
    def self.getCommandClass(name)
      commandClass = @@commandClasses[name]
      if not commandClass
        raise ParseException.new("No command class named #{name.inspect}")
      end
      return commandClass
    end
    
    def self.register(name)
      @@commandClasses[name] = self
    end
    
    def forceClose
      raise ParseException("Failed to close command properly")
    end
  end
  
  class Properties<RejennerCommand
    register "properties"
    
    def initialize
      @properties = {}
    end
    
    def addLine(line)
      propertyLineMatch = /^\s*(\w*)\s*=(.*)$/.match(line)
      if not propertyLineMatch
        raise ParseException.new("Invalid property line: #{line.inspect}")
      end
      name = propertyLineMatch[1]
      value = propertyLineMatch[2].strip
      @properties[name] = value
      puts "Properties = #{@properties.inspect}"
    end

    def closeActiveCommentInput
      # do nothing, OK to close active comment input
    end
  end
  
  def self.rejenerate(fileName)
    Rejenner.new(fileName).rejenerate
  end
end

class Header<Rejenner::RejennerCommand
  register "header"
  
  def readsLines
    false
  end
end

if ARGV.length > 0
  Rejenner.rejenerate(ARGV[0])
end
