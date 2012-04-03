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
      return line
    end
    
    def forceClose(reason)
      # do nothing, OK to force it to close
    end
    
    def closeCommentInput
        raise ParseException("End comment for input region found, but no input is active")
    end
    
    def endInputCommand(commandName, rest)
      raise ParseException("End input command found, but no input is active")
    end
    
    def startOutput(commandName, rest)
      raise ParseException("Found output for command #{commandName.inspect}, but there is no preceding command")
    end

    def endOutput(commandName, rest)
      raise ParseException("Found end of output for command #{commandName.inspect}, but there is no preceding command")
    end
    
  end
  
  class Rejenner
    
    def initialize(fileName)
      @fileName = fileName
      @currentCommand = NonCommandLines.new()
      @savedCommands = [@currentCommand]
    end
    
    def startInputCommand(commandName, rest, commentClosed)
      @currentCommand.forceClose("New input for command #{commandName} started")
      @currentCommand = RejennerCommand.getCommandClass(commandName).new()
      @savedCommands << @currentCommand
      @currentCommand.commentClosed = commentClosed
      @currentCommand.name = commandName
    end
    
    def processCommentMatch(hashes, isEnd, command, rest, commentClosed)
      puts "# COMMENT match: #{hashes.inspect}, #{isEnd.inspect}, #{command.inspect}, #{rest.inspect}, #{commentClosed.inspect}"
      case hashes
      when "#" 
        if isEnd
          @activeCommand.endInputCommand(commandName, rest)
        else
          startInputCommand(commandName, rest, commentClosed)
        end
      when "##"
        if isEnd
          @activeCommand.endOutput(command, rest)
        else
          @activeCommand.startOutput(command, rest)
        end
      else
        raise ParseException.new("More than 2 # characters")
      end
    end
    
    def processEndCommentMatch
      puts "# COMMENT end"
      @activeCommand.closeCommentInput
    end
    
    def processNonCommandLine(line)
      puts "# LINE: #{line}"
      lineAccepted = @activeCommand.addLine(line)
      if not lineAccepted
        @activeCommand = NonCommandLines.new()
        @savedCommands << @activeCommand
      end
    end
    
    def parseLine(line)
      rejennerCommentMatch = /^<!--\s*(#+)(end\s+|)\s*(\w*)\s*(.*)$/.match(line)
      if rejennerCommentMatch
        hashes = rejennerCommentMatch[1]
        endString = rejennerCommentMatch[2]
        command = rejennerCommentMatch[3].downcase
        rest = rejennerCommentMatch[4].rstrip
        closeCommentMatch = /^(.*)-->$/.match(rest)
        commentClosed = closeCommentMatch != nil
        if commentClosed
          rest = closeCommentMatch[1]
        processCommentMatch(hashes, endString == "end", command, rest, commentClosed)
      else
        endRejennerCommentMatch = /^#\s*-->\s*$/.match(line)
        if endRejennerCommentMatch
          processEndCommentMatch
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
          puts "ERROR: #{message}"
          raise pe
        end
      end
      @activeCommand.forceClose("End of file found")
    end
  end
  
  class RejennerCommand
    @@commandClasses = {}
    
    attr :commentClosed, :name
    
    def initialize
      @commentClosed = false
      @readingInput = true
      @readingOutput = false
      @closed = false
      @inputLines = []
      @outputLines = []
      @name = nil
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
    
    def closeCommentInput
      if @commentClosed
        raise ParseException("Found end of comment input, but command start comment is already closed")
      end
      if @readingInput
        @readingInput = false
      end
    end
    
    def endInputCommand(commandName, rest)
      if commandName != name
        raise ParseException("Found end input command, but name at end #{commandName.inspect} " + 
                             "does not match name at start #{name.inspect}")
      end
      if @readingInput
        if not @commentClosed
          raise ParseException("Found end input command, but input is inside a comment")
        end
        @readingInput = false
      else
        raise ParseException("Found end input command, but input has already ended")
      end
    end
    
    def startOutput(commandName, rest)
      if commandName != name
        raise ParseException("Found command output, but name #{commandName.inspect} " + 
                             "does not match name of command #{name.inspect}")
      end
      if @readingInput
        if not @commentClosed
          raise ParseException("Found output for command #{commandName.inspect}, but we are still inside input comment")
        end
        @readingInput = false
      end
      if @readingOutput
          raise ParseException("Found output for command #{commandName.inspect}, but we are already in the output")
      end
      @readingOutput = true
    end
    
    def endOutput(commandName, rest)
      if commandName != name
        raise ParseException("Found command output end, but name #{commandName.inspect} " + 
                             "does not match name of command #{name.inspect}")
      end
      if not @readingOutput
        raise ParseException("Found output end for command #{commandName.inspect}, but output has not started")
      end
      @readingOutput = false
      @closed = true
    end
    
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
    
    
  end
  
  class Properties<RejennerCommand
    register "properties"
    
    def initialize
      super.initialize
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

class Header<Rejenner::RejennerCommand
  register "header"
  
  def readsLines
    false
  end
end

if ARGV.length > 0
  Rejenner.rejenerate(ARGV[0])
end
