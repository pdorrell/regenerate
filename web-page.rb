
module Rejenner
  
  # A component, which includes a sequence of lines which make up the text of that component
  class PageComponent
    attr_reader :text
    def initialize
      @lines = []
      @text = nil # if text is nil, component is not yet finished
    end
    
    def processStartComment(parsedCommentLine)
      @startName = parsedCommentLine.name
      initializeFromStartComment(parsedCommentLine)
      if parsedCommentLine.sectionEnd # section end in start comment line, so already finished
        finishText
      end
    end
    
    def processEndComment(parsedCommentLine)
      finishText
      if parsedCommentLine.name != @startName
        raise ParseException.new("Name #{parsedCommentLine.name.inspect} in end comment doesn't match name #{@startName.inspect} in start comment.")
      end
    end
    
    def initializeFromStartComment(parsedCommentLine)
      # default do nothing
    end
    
    def finished
      @text != nil
    end
    
    def addLine(line)
      @lines << line
    end
    
    def finishText
      @text = @lines.join("\n") + "\n"
    end
  end
  
  # A component of static text which is not assigned to any variable, and which does not change
  class StaticHtml<PageComponent
    def output(showSource, showResult)
      text
    end
    
    def varName
      nil
    end
  end
  
  class RubyCode<PageComponent
    
    def output(showSource)
      if showSource
        "<!-- [ruby -->\n#{text}\n<!-- ruby] -->\n"
      else
        ""
      end
    end
  end
  
  # Base class for the text variable types
  class TextVariable<PageComponent
    attr_reader :varName
    
    def initializeFromStartComment(parsedCommentLine)
      @varName = parsedCommentLine.instanceVarName
    end
    
    def initialize(varName)
      super
      @varName = varName
    end
    
  end
  
  # HtmlVariable Can be both source and result
  class HtmlVariable < TextVariable
    
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if !parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for HTML variable does not have a comment start")
      end
    end

    def output(showSource)
      if showSource
        if text = nil || text = ""
          "<!-- [#{@varName}] -->\n"
        else
          "<!-- [#{@varName} -->\n#{text}\n<!-- #{@varName}] -->\n"
        end
      else
        text
      end
    end
  end
  
  # SourceCommentVariable Is an input only
  class SourceCommentVariable
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for comment variable has an unexpected comment start")
      end
    end

    def output(showSource)
      if showSource
          "<!-- [#{@varName}\n#{text}\n#{@varName}] -->\n"
      else
        ""
      end
    end
  end
  
  COMMENT_LINE_REGEX = /^\s*(<!--\s*|)(\[|)((@|)[_a-zA-Z][_a-zA-Z0-9]*)(\]|)(\s*-->|)?\s*$/
  
  class ParseException<Exception
  end
  
  class ParsedRejennerCommentLine
    
    attr_reader :isInstanceVar, :hasCommentStart, :hasCommentEnd, :sectionStart, :sectionEnd
    attr_reader :isEmptySection, :line
    
    def initialize(line, match)
      @hasCommentStart = match[1] != ""
      @sectionStart = match[2] != ""
      @isInstanceVar = match[4] != ""
      @name = match[3]
      @sectionEnd = match[5] != ""
      @hasCommentEnd = match[6] != ""
      @line = line
      @isEmptySection = @sectionStart && @sectionEnd
    end
    
    def to_s
      "#{@hasCommentStart ? "<!-- ":""}#{@sectionStart ? "[ ":""}#{@isInstanceVar ? "@ ":""}#{@name.inspect}#{@sectionEnd ? " ]":""}#{@hasCommentEnd ? " -->":""}"
    end
    
    def isRejennerCommentLine
      return (@hasCommentStart || @hasCommentEnd) && (@sectionStart || @sectionEnd)
    end
    
    def isRuby
      !@isInstanceVar && @name == "ruby"
    end
    
    def instanceVarName
      return "@" + @name
    end
    
    def raiseParseException(message)
      raise ParseException.new("Error parsing line #{@line.inspect}: #{message}")
    end
    
    # only call this method if isRejennerCommentLine returns true
    def checkIsValid
      if !@isInstanceVar and !["ruby"].include?(@name)
        raiseParseException("Unknown section name #{@name.inspect}")
      end
      if @isEmptySection and (!@hasCommentStart && !@hasCommentEnd)
        raiseParseException("Empty section, but is not a closed comment")
      end
      if !@sectionStart && !@hasCommentEnd
        raiseParseException("End of section in comment start")
      end
      if !@sectionEnd && !@hasCommentStart
        raiseParseException("Start of section in comment end")
      end
      if (@sectionStart && @sectionEnd) && isRuby
        raiseParseException("Empty ruby section")
      end
    end
    
  end

  class WebPage
    attr_reader :fileName
    
    def initialize(fileName)
      @fileName = fileName
      @components = []
      @currentComponent = nil
      readFileLines
    end
    
    def processTextLine(line, lineNumber)
      puts "text: #{line}"
    end
    
    def processCommandLine(line, lineNumber)
      puts "command: #{line}"
    end
    
    
    def readFileLines
      puts "Opening #{@fileName} ..."
      lineNumber = 0
      File.open(@fileName).each_line do |line|
        line.chomp!
        lineNumber += 1
        #puts "line #{@lineNumber}: #{line}"
        commentLineMatch = COMMENT_LINE_REGEX.match(line)
        if commentLineMatch
          parsedCommentLine = ParsedRejennerCommentLine.new(line, commentLineMatch)
          if parsedCommentLine.isRejennerCommentLine
            parsedCommentLine.checkIsValid
            processCommandLine(parsedCommentLine, @lineNumber)
          else
            processTextLine(line, @lineNumber)
          end
        else
          processTextLine(line, @lineNumber)
        end
      end
    end
  end
  
end
