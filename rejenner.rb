# A framework for static website generation which regenerates files in place.

module Rejenner
  
  class ParseException<Exception
  end
  
  class NonCommandLines
    def initialize
      @lines = []
    end
    
    def hasContent?
      return @lines.length > 0
    end
    
    def process
    end
    
    def addLine(line)
      @lines << line
      return true
    end
    
    def forceClose(reason)
      # do nothing, OK to force it to close
    end
    
    def closeCommentInput(line)
      raise ParseException.new("End comment for input region found, but no input is active")
    end
    
    def endInputCommand(commandName, rest, line)
      raise ParseException.new("End input command found, but no input is active")
    end
    
    def startOutput(commandName, rest)
      raise ParseException.new("Found output for command #{commandName.inspect}, but there is no preceding command")
    end
    
    def endOutput(commandName, rest)
      raise ParseException.new("Found end of output for command #{commandName.inspect}, but there is no preceding command")
    end
    
  end
  
  class Rejenner
    
    def initialize(fileName)
      @fileName = fileName
      @currentCommand = NonCommandLines.new()
      @savedCommands = [@currentCommand]
    end
    
    def startInputCommand(commandName, rest, commentClosed, line)
      puts "startInputCommand, commandName = #{commandName.inspect}, commentClosed = #{commentClosed}"
      @currentCommand.forceClose("New input for command #{commandName} started")
      @currentCommand = RejennerCommand.getCommandClass(commandName).new()
      @currentCommand.lineBeforeInput = line
      @savedCommands << @currentCommand
      @currentCommand.commentClosed = commentClosed
      @currentCommand.name = commandName
    end
    
    def processCommentMatch(hashes, isEnd, commandName, rest, commentClosed, line)
      puts ("# COMMENT match: #{hashes.inspect}, #{isEnd.inspect}, #{commandName.inspect}, " + 
            "#{rest.inspect}, #{commentClosed.inspect}")
      case hashes
      when "#" 
        if isEnd
          @currentCommand.endInputCommand(commandName, rest, line)
        else
          startInputCommand(commandName, rest, commentClosed, line)
        end
      when "##"
        if isEnd
          @currentCommand.endOutput(commandName, rest)
        else
          @currentCommand.startOutput(commandName, rest)
        end
      else
        raise ParseException.new("More than 2 # characters")
      end
    end
    
    def processEndCommentMatch(line)
      puts "# COMMENT end"
      @currentCommand.closeCommentInput(line)
    end
    
    def processNonCommandLine(line)
      puts "# LINE: #{line}"
      lineAccepted = @currentCommand.addLine(line)
      if not lineAccepted
        @currentCommand = NonCommandLines.new()
        @savedCommands << @currentCommand
      end
    end
    
    def parseLine(line)
      rejennerCommentMatch = /^<!--\s*(#+)((end)\s+|)\s*(\w*)\s*(.*)$/.match(line)
      if rejennerCommentMatch
        hashes = rejennerCommentMatch[1]
        endString = rejennerCommentMatch[3]
        command = rejennerCommentMatch[4].downcase
        rest = rejennerCommentMatch[5].rstrip
        closeCommentMatch = /^(.*)-->$/.match(rest)
        commentClosed = closeCommentMatch != nil
        if commentClosed
          rest = closeCommentMatch[1]
        end
        processCommentMatch(hashes, endString == "end", command, rest, commentClosed, line)
      else
        endRejennerCommentMatch = /^#\s*-->\s*$/.match(line)
        if endRejennerCommentMatch
          processEndCommentMatch(line)
        else
          processNonCommandLine(line)
        end
      end
    end
      
    def rejenerate
      puts "Opening #{@fileName} ..."
      @lineNumber = 0
      File.open(@fileName).each_line do |line|
        @lineNumber += 1
        @currentLine = line
        puts "line #{@lineNumber}: #{line}"
        begin
          parseLine(line)
        rescue ParseException => pe
          puts "#{@fileName}:#{@lineNumber}: #{@currentLine}"
          puts "ERROR: #{pe.message}"
          raise pe
        end
      end
      @currentCommand.forceClose("End of file found")
    end
  end
  
  class RejennerCommand
    @@commandClasses = {}
    
    attr_accessor :commentClosed, :name, :lineBeforeInput
    
    def initialize
      @commentClosed = false
      @readingInput = true
      @readingOutput = false
      @closed = false
      @lineBeforeInput = nil
      @inputLines = []
      @lineAfterInput = nil
      @outputLines = []
      @name = nil
    end
    
    def hasContent?
      true
    end
    
    def forceClose(reason)
      if @readingInput
        raise ParseException ("#{reason}, but still reading input from command #{name}")
      end
      if @readingOutput
        raise ParseException ("#{reason}, but still reading output from command #{name}")
      end
    end
    
    def addLine(line)
      if @readingInput
        @inputLines << line
        return true
      elsif @readingOutput
        @outputLines << line
        return true
      else
        return false
      end
    end
    
    def closeCommentInput(line)
      if @commentClosed
        raise ParseException.new("Found end of comment input, but command start comment is already closed")
      end
      if @readingInput
        @readingInput = false
        @lineAfterInput = line
      else
        raise ParseException.new("Found end of comment input, but not reading input")
      end
    end
    
    def endInputCommand(commandName, rest, line)
      if commandName != name
        raise ParseException.new("Found end input command, but name at end #{commandName.inspect} " + 
                             "does not match name at start #{name.inspect}")
      end
      if @readingInput
        if not @commentClosed
          raise ParseException.new("Found end input command, but input is inside a comment")
        end
        @readingInput = false
        @lineAfterInput = line
      else
        raise ParseException.new("Found end input command, but input has already ended")
      end
    end
    
    def startOutput(commandName, rest)
      if commandName != name
        raise ParseException.new("Found command output, but name #{commandName.inspect} " + 
                             "does not match name of command #{name.inspect}")
      end
      if @readingInput
        if not @commentClosed
          raise ParseException.new("Found output for command #{commandName.inspect}, but we are still inside input comment")
        end
        @readingInput = false
      end
      if @readingOutput
          raise ParseException.new ("Found output for command #{commandName.inspect}, but we are already in the output")
      end
      @readingOutput = true
    end
    
    def endOutput(commandName, rest)
      if commandName != name
        raise ParseException.new("Found command output end, but name #{commandName.inspect} " + 
                             "does not match name of command #{name.inspect}")
      end
      if not @readingOutput
        raise ParseException.new("Found output end for command #{commandName.inspect}, but output has not started")
      end
      @readingOutput = false
      @closed = true
    end
    
    def self.getCommandClass(name)
      puts "getCommandClass #{name.inspect}, @@commandClasses = #{@@commandClasses.inspect}"
      commandClass = @@commandClasses[name]
      if not commandClass
        raise ParseException.new("No command class named #{name.inspect}")
      end
      puts "commandClass = #{commandClass.inspect}"
      return commandClass
    end
    
    def self.register(name)
      puts " registering #{name} => #{self.inspect}"
      @@commandClasses[name] = self
    end
    
    
  end
  
  class Properties<RejennerCommand
    register "properties"
    
    def initialize
      super
      @properties = {}
    end
    
    def process
      for line in @inputLines do
        propertyLineMatch = /^\s*(\w*)\s*=(.*)$/.match(line)
        if not propertyLineMatch
          raise ParseException.new("Invalid property line: #{line.inspect}")
        end
        name = propertyLineMatch[1]
        value = propertyLineMatch[2].strip
        @properties[name] = value
      end
      puts "Properties = #{@properties.inspect}"
    end

  end
  
  def self.rejenerate(fileName)
    Rejenner.new(fileName).rejenerate
  end
end

if ARGV.length > 1
  Rejenner.rejenerate(ARGV[0])
end
