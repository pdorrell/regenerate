require 'set'
require 'erb'
require 'json'
require 'regenerate/regenerate-utils.rb'

module Regenerate
  
  # The textual format for "regeneratable" files is HTML (or XML) with special comment lines that mark the beginnings
  # and ends of particular "page components". Such components may include actual HTML (or XML) in which case there 
  # are special start & end comment lines, they may consist entirely of one comment.
  
  # Base class for page components, defined by a sequence of lines in an HTML file which make up the text of that component
  class PageComponent
    attr_reader :text
    attr_accessor :parentPage
    
    def initialize
      @lines = []
      @text = nil # if text is nil, component is not yet finished
      @parentPage = nil
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
    
    def addToParentPage
      # default do nothing
    end
    
    def finishText
      @text = @lines.join("\n")
      addToParentPage
    end
  end
  
  # A component of static text which is not assigned to any variable, and which does not change when re-generated.
  # Any sequence of line _not_ marked by special start and end lines will constitute static HTML.
  class StaticHtml < PageComponent
    def output(showSource = true)
      text + "\n"
    end
    
    def varName
      nil
    end
  end
  
  # A component consisting of Ruby code which is to be evaluated in the context of the object that defines the page
  # Defined by start line "<!-- [ruby" and end line "ruby] -->".
  class RubyCode<PageComponent
    
    attr_reader :lineNumber
    
    def initialize(lineNumber)
      super()
      @lineNumber = lineNumber
    end
    
    def output(showSource = true)
      if showSource
        "<!-- [ruby\n#{text}\nruby] -->\n"
      else
        ""
      end
    end
    
    def addToParentPage
      @parentPage.addRubyComponent(self)
    end
  end

  # A component consisting of a single line which specifies the Ruby class which represents this page
  # In the format "<!-- [class <classname>] -->" where <classname> is the name of a Ruby class.
  # The Ruby class should generally have Regenerate::PageObject as a base class.
  class SetPageObjectClass<PageComponent
    attr_reader :className
    def initialize(className)
      super()
      @className = className
    end
    
    def output(showSource = true)
      if showSource
        "<!-- [class #{@className}] -->\n"
      else
        ""
      end
    end
    
    def addToParentPage
      @parentPage.setPageObject(@className)
    end
  end
  
  # Base class for a component defining a block of text (which may or may not be inside a comment)
  # which is assigned to an instance variable of the object representing the page. (The text value for
  # this instance variable may be both read and written by the Ruby code that runs in the context of the object.)
  class TextVariable<PageComponent
    attr_reader :varName
    
    def initializeFromStartComment(parsedCommentLine)
      @varName = parsedCommentLine.instanceVarName
    end
    
    def addToParentPage
      #puts "TextVariable.addToParentPage #{@varName} = #{@text.inspect}"
      @parentPage.setPageObjectInstanceVar(@varName, @text)
    end
    
    def textVariableValue
      @parentPage.getPageObjectInstanceVar(@varName)
    end
  end
  
  # HtmlVariable 
  class HtmlVariable < TextVariable
    
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if !parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for HTML variable does not have a comment start")
      end
    end
    
    def output(showSource = true)
      if showSource
        textValue = textVariableValue
        if textValue == nil || textValue == ""
          "<!-- [#{@varName}] -->\n"
        else
          "<!-- [#{@varName} -->\n#{textValue}\n<!-- #{@varName}] -->\n"
        end
      else
        text
      end
    end
  end
  
  # CommentVariable Is an input only
  class CommentVariable < TextVariable
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for comment variable has an unexpected comment start")
      end
    end
    
    def output(showSource = true)
      if showSource
        "<!-- [#{@varName}\n#{textVariableValue}\n#{@varName}] -->\n"
      else
        ""
      end
    end
  end
  
  COMMENT_LINE_REGEX = /^\s*(<!--\s*|)(\[|)((@|)[_a-zA-Z][_a-zA-Z0-9]*)(|\s+([_a-zA-Z0-9]*))(\]|)(\s*-->|)?\s*$/
  
  class ParseException<Exception
  end
  
  class ParsedRegenerateCommentLine
    
    attr_reader :isInstanceVar, :hasCommentStart, :hasCommentEnd, :sectionStart, :sectionEnd
    attr_reader :isEmptySection, :line, :name, :value
    
    def initialize(line, match)
      @hasCommentStart = match[1] != ""
      @sectionStart = match[2] != ""
      @isInstanceVar = match[4] != ""
      @name = match[3]
      @value = match[6]
      @sectionEnd = match[7] != ""
      @hasCommentEnd = match[8] != ""
      @line = line
      @isEmptySection = @sectionStart && @sectionEnd
    end
    
    def to_s
      "#{@hasCommentStart ? "<!-- ":""}#{@sectionStart ? "[ ":""}#{@isInstanceVar ? "@ ":""}#{@name.inspect}#{@value ? " "+@value:""}#{@sectionEnd ? " ]":""}#{@hasCommentEnd ? " -->":""}"
    end
    
    def isRejennerCommentLine
      return (@hasCommentStart || @hasCommentEnd) && (@sectionStart || @sectionEnd)
    end
    
    def isRuby
      !@isInstanceVar && @name == "ruby"
    end
    
    def instanceVarName
      return @name
    end
    
    def raiseParseException(message)
      raise ParseException.new("Error parsing line #{@line.inspect}: #{message}")
    end
    
    # only call this method if isRejennerCommentLine returns true
    def checkIsValid
      if !@isInstanceVar and !["ruby", "class"].include?(@name)
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
  
  class UnexpectedChangeError<Exception
  end
  
  class WebPage
    
    include Regenerate::Utils
    
    attr_reader :fileName
    
    def initialize(fileName)
      @fileName = fileName
      @components = []
      @currentComponent = nil
      @componentInstanceVariables = {}
      initializePageObject(PageObject.new)  # default, can be overridden by SetPageObjectClass
      @rubyComponents = []
      readFileLines
    end
    
    def initializePageObject(pageObject)
      @pageObject = pageObject
      setPageObjectInstanceVar("@fileName", @fileName)
      setPageObjectInstanceVar("@baseDir", File.dirname(@fileName))
      setPageObjectInstanceVar("@baseFileName", File.basename(@fileName))
      @initialInstanceVariables = Set.new(@pageObject.instance_variables)
    end
    
    def getPageObjectInstanceVar(varName)
      @pageObject.instance_variable_get(varName)
    end
    
    def setPageObjectInstanceVar(varName, value)
      puts " setPageObjectInstanceVar, #{varName} = #{value.inspect}"
      @pageObject.instance_variable_set(varName, value)
    end
    
    def addRubyComponent(rubyComponent)
      @rubyComponents << rubyComponent
    end
    
    def setInstanceVarValue(varName, value)
      if @initialInstanceVariables.member? varName
        raise Exception, "Instance variable #{varName} is a pre-existing instance variable"
      end
      if @componentInstanceVariables.member? varName
        raise Exception, "Instance variable #{varName} is a already defined for a component"
      end
      instance_variable_set(varName, value)
      componentInstanceVariables << varName
    end
    
    def startNewComponent(component, startComment = nil)
      
      component.parentPage = self
      @currentComponent = component
      #puts "startNewComponent, @currentComponent = #{@currentComponent.inspect}"
      @components << component
      if startComment
        component.processStartComment(startComment)
      end
    end
    
    def processTextLine(line, lineNumber)
      #puts "text: #{line}"
      if @currentComponent == nil
        startNewComponent(StaticHtml.new)
      end
      @currentComponent.addLine(line)
    end
    
    def classFromString(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end
    
    def setPageObject(className)
      pageObjectClass = classFromString(className)
      initializePageObject(pageObjectClass.new)
    end
    
    def processCommandLine(parsedCommandLine, lineNumber)
      #puts "command: #{parsedCommandLine}"
      if @currentComponent && (@currentComponent.is_a? StaticHtml)
        @currentComponent.finishText
        @currentComponent = nil
      end
      if @currentComponent
        if parsedCommandLine.sectionStart
          raise ParseException.new("Unexpected section start #{parsedCommandLine} inside component")
        end
        @currentComponent.processEndComment(parsedCommandLine)
        @currentComponent = nil
      else
        if !parsedCommandLine.sectionStart
          raise ParseException.new("Unexpected section end #{parsedCommandLine}, outside of component")
        end
        if parsedCommandLine.isInstanceVar
          if parsedCommandLine.hasCommentEnd
            startNewComponent(HtmlVariable.new, parsedCommandLine)
          else
            startNewComponent(CommentVariable.new, parsedCommandLine)
          end
        else
          if parsedCommandLine.name == "ruby"
            startNewComponent(RubyCode.new(lineNumber+1), parsedCommandLine)
          elsif parsedCommandLine.name == "class"
            startNewComponent(SetPageObjectClass.new(parsedCommandLine.value), parsedCommandLine)
          else
            raise ParseException.new("Unknown section type #{parsedCommandLine.name.inspect}")
          end
        end
        if @currentComponent.finished
          @currentComponent = nil
        end
      end
      
    end
    
    def finish
      if @currentComponent
        if @currentComponent.is_a? StaticHtml
          @currentComponent.finishText
          @currentComponent = nil
        else
          raise ParseException.new("Unfinished last component at end of file")
        end
      end
    end
    
    def diffReport(newString, oldString)
      i = 0
      minLength = [newString.length, oldString.length].min
      while i<minLength and newString[i] == oldString[i] do
        i += 1
      end
      diffPos = i
      newStringEndPos = [diffPos+20,newString.length].min
      oldStringEndPos = [diffPos+20, newString.length].min
      startPos = [0, diffPos-10].max
      "Different from position #{diffPos}: \n  #{newString[startPos...newStringEndPos].inspect}\n !=\n  #{oldString[startPos...newStringEndPos].inspect}"
    end
    
    def checkOutputFileUnchanged(outFile, oldFile)
      if File.exists? oldFile
        oldFileContents = File.read(oldFile)
        newFileContents = File.read(outFile)
        if oldFileContents != newFileContents
          newFileName = outFile + ".new"
          File.rename(outFile, newFileName)
          File.rename(oldFile, outFile)
          raise UnexpectedChangeError.new("New file #{newFileName} is different from old file #{outFile}: #{diffReport(newFileContents,oldFileContents)}")
        end
      else
        raise UnexpectedChangeError.new("Can't check #{outFile} against backup #{oldFile} " + 
                                        "because backup file doesn't exist")
      end
    end
    
    def writeRegeneratedFile(outFile, checkNoChanges)
      backupFileName = makeBackupFile(outFile)
      puts "Outputting regenerated page to #{outFile} ..."
      File.open(outFile, "w") do |f|
        for component in @components do
          f.write(component.output)
        end
      end
      puts "Finished writing #{outFile}"
      if checkNoChanges
        checkOutputFileUnchanged(outFile, backupFileName)
      end
    end
    
    def readFileLines
      puts "Opening #{@fileName} ..."
      lineNumber = 0
      File.open(@fileName).each_line do |line|
        line.chomp!
        lineNumber += 1
        #puts "line #{lineNumber}: #{line}"
        commentLineMatch = COMMENT_LINE_REGEX.match(line)
        if commentLineMatch
          parsedCommandLine = ParsedRegenerateCommentLine.new(line, commentLineMatch)
          #puts "parsedCommandLine = #{parsedCommandLine}"
          if parsedCommandLine.isRejennerCommentLine
            parsedCommandLine.checkIsValid
            processCommandLine(parsedCommandLine, lineNumber)
          else
            processTextLine(line, lineNumber)
          end
        else
          processTextLine(line, lineNumber)
        end
      end
      finish
      #puts "Finished reading #{@fileName}."
    end
    
    def regenerate
      executeRubyComponents
      writeRegeneratedFile(@fileName)
      #display
    end
    
    def regenerateToOutputFile(outFile, checkNoChanges = false)
      executeRubyComponents
      writeRegeneratedFile(outFile, checkNoChanges)
    end
    
    def executeRubyComponents
      fileDir = File.dirname(@fileName)
      puts "Executing ruby components in directory #{fileDir} ..."
      Dir.chdir(fileDir) do
        for rubyComponent in @rubyComponents
          rubyCode = rubyComponent.text
          puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
          puts "Executing ruby (line #{rubyComponent.lineNumber}) #{rubyCode.inspect} ..."
          @pageObject.instance_eval(rubyCode, @fileName, rubyComponent.lineNumber)
          #puts "Finished executing ruby at line #{rubyComponent.lineNumber}"
        end
      end
      #puts "Finished executing ruby components."
    end
    
    def display
      puts "=========================================================================="
      puts "Output of #{@fileName}"
      for component in @components do
        puts "--------------------------------------"
        puts(component.output)
      end
    end
  end
  
  class PageObject
    include Regenerate::Utils
    
    def erb(templateFileName)
      @binding = binding
      File.open(relative_path(templateFileName), "r") do |input|
        templateText = input.read
        template = ERB.new(templateText, nil, nil)
        template.filename = templateFileName
        result = template.result(@binding)
      end
    end
    
    def erbFromString(templateString)
      @binding = binding
      template = ERB.new(templateString, nil, nil)
      template.result(@binding)
    end
      
    
    def relative_path(path)
      File.expand_path(File.join(@baseDir, path.to_str))
    end

    def require_relative(path)
      require relative_path(path)
    end
    
    def saveProperties
      properties = {}
      for property in propertiesToSave
        value = instance_variable_get("@" + property.to_s)
        properties[property] = value
      end
      propertiesFileName = relative_path(self.class.propertiesFileName(@baseFileName))
      puts "Saving properties #{properties.inspect} to #{propertiesFileName}"
      ensureDirectoryExists(File.dirname(propertiesFileName))
      File.open(propertiesFileName,"w") do |f|
        f.write(JSON.pretty_generate(properties))
      end
    end

  end
  
end
