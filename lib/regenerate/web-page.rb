require 'set'
require 'erb'
require 'json'
require 'regenerate/regenerate-utils.rb'

module Regenerate
  
  # The textual format for "regeneratable" files is HTML (or XML) with special comment lines that mark the beginnings
  # and ends of particular "page components". Such components may include actual HTML (or XML) in which case there 
  # are special start & end comment lines, or, they may consist entirely of one multi-line comment.
  
  # Base class for page components, defined by a sequence of lines in an HTML file which make up the text of that component
  class PageComponent
    attr_reader :text
    attr_accessor :parentPage
    
    def initialize
      @lines = [] # No lines of text yet
      @text = nil # if text is nil, component is not yet finished
      @parentPage = nil # A link to the parent WebPage object, will get set from a method on that object
    end
    
    def processStartComment(parsedCommentLine)
      @startName = parsedCommentLine.name # remember the name in the start command, 
                                          # because it has to match the name in the end command
      initializeFromStartComment(parsedCommentLine) # do whatever has to be done to initialise this page component
      if parsedCommentLine.sectionEnd # section end in start comment line, so already finished
        finishText # i.e. there will be no more text lines added to this component
      end
    end
    
    def processEndComment(parsedCommentLine)
      finishText # there will be no more text lines added to this component
      if parsedCommentLine.name != @startName # check match of name in end comment with name in start comment
        raise ParseException.new("Name #{parsedCommentLine.name.inspect} in end comment doesn't match name #{@startName.inspect} in start comment.")
      end
    end

    # Do whatever needs to be done to initialise this page component from the start command
    def initializeFromStartComment(parsedCommentLine)
      # default do nothing - over-ride this method in derived classes
    end
    
    # Has this component finished
    def finished
      @text != nil # finishText sets the value of @text, so use that as a test for "is it finished?"
    end
    
    # Add a text line, by adding it to @lines
    def addLine(line)
      @lines << line
    end
    
    # Do whatever needs to be done to the parent WebPage object for this page component
    def addToParentPage
      # default do nothing - over-ride this in derived classes
    end
    
    # After all text lines have been added, join them together and put into @text
    def finishText
      @text = @lines.join("\n")
      addToParentPage # do whatever needs to be done to the parent WebPage object for this page component
    end
  end
  
  # A page component of static text which is not assigned to any variable, and which does not change when re-generated.
  # Any sequence of line _not_ marked by special start and end lines will constitute static HTML.
  class StaticHtml < PageComponent
    
    # output the text as is (but with an extra eoln)
    def output(showSource = true)
      text + "\n"
    end
    
    # varName is nil because no instance variable is associated with a static HTML page component
    def varName
      nil
    end
  end
  
  # A page component consisting of Ruby code which is to be evaluated in the context of the object that defines the page
  # Defined by start line "<!-- [ruby" and end line "ruby] -->".
  class RubyCode < PageComponent
    
    # The line number, which matters for code evaluation so that Ruby can populate stack traces correctly
    attr_reader :lineNumber
    
    # Initialise this page component, additionally initialising the line number
    def initialize(lineNumber)
      super()
      @lineNumber = lineNumber
    end
    
    # Output this page component in a form that would be reparsed back into the same page component
    def output(showSource = true)
      if showSource
        "<!-- [ruby\n#{text}\nruby] -->\n"
      else
        ""
      end
    end
    
    # Add to parent page, which requires adding to the page's list of Ruby page components (which will all
    # get executed at some later stage)
    def addToParentPage
      @parentPage.addRubyComponent(self)
    end
  end

  # A page component consisting of a single line which specifies the Ruby class which represents this page
  # In the format "<!-- [class <classname>] -->" where <classname> is the name of a Ruby class.
  # The Ruby class should generally have Regenerate::PageObject as a base class.
  class SetPageObjectClass < PageComponent
    
    attr_reader :className # The name of the Ruby class of the page object
    
    # Initialise this page component, additionally initialising the class name    
    def initialize(className)
      super()
      @className = className
    end
    
    # Output this page component in a form that would be reparsed back into the same page component
    def output(showSource = true)
      if showSource
        "<!-- [class #{@className}] -->\n"
      else
        ""
      end
    end
    
    def addToParentPage
      # Add to parent page, which creates a new page object of the specified class (replacing the default PageObject object)
      @parentPage.setPageObject(@className)
    end
  end
  
  # Base class for a page component defining a block of text (which may or may not be inside a comment)
  # which is assigned to an instance variable of the object representing the page. (The text value for
  # this instance variable may be both read and written by the Ruby code that runs in the context of the object.)
  class TextVariable<PageComponent
    attr_reader :varName # the name of the instance variable of the page object that will hold this value
    
    # initialise, which sets the instance variable name
    def initializeFromStartComment(parsedCommentLine)
      @varName = parsedCommentLine.instanceVarName
    end
    
    # add to parent WebPage by adding the specified instance variable to the page object
    def addToParentPage
      #puts "TextVariable.addToParentPage #{@varName} = #{@text.inspect}"
      @parentPage.setPageObjectInstanceVar(@varName, @text)
    end
    
    # Get the textual value of the page object instance variable
    def textVariableValue
      @parentPage.getPageObjectInstanceVar(@varName)
    end
  end
  
  # A page component for a block of HTML which is assigned to an instance variable of the page object
  class HtmlVariable < TextVariable
    
    # Process the end command by finishing the page component definition, also check that the closing
    # command has the correct form (must be a self-contained HTML comment line)
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if !parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for HTML variable does not have a comment start")
      end
    end
    
    # Output in a form that would be reparsed as the same page component, but with whatever the current
    # textual value of the associate page object instance variable is.
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
  
  # A page component for text inside an HTML comment which is assigned to an instance variable of the page object
  class CommentVariable < TextVariable
    
    # Process the end command by finishing the page component definition, also check that the closing
    # command has the correct form (must be a line that ends an existing HTML comment)
    def processEndComment(parsedCommentLine)
      super(parsedCommentLine)
      if parsedCommentLine.hasCommentStart
        raise ParseException.new("End comment for comment variable has an unexpected comment start")
      end
    end
    
    # Output in a form that would be reparsed as the same page component, but with whatever the current
    # textual value of the associate page object instance variable is.
    def output(showSource = true)
      if showSource
        "<!-- [#{@varName}\n#{textVariableValue}\n#{@varName}] -->\n"
      else
        ""
      end
    end
  end
  
  # Regex that matches Regenerate comment line, with following components:
  # * Optional whitespace
  # * Possible ("<!--" + optional whitespace)
  # * Possible "["
  # * Possible Ruby identifier (alphanumeric or underscore with initial non-numeric) with optional "@" prefix
  # * Possible (whitespace + alphanumeric/underscore value)
  # * Possible "]"
  # * Possible (optional whitespace + "-->")
  # * Optional whitespace
  COMMENT_LINE_REGEX = /^\s*(<!--\s*|)(\[|)((@|)[_a-zA-Z][_a-zA-Z0-9]*)(|\s+([_a-zA-Z0-9]+))(\]|)(\s*-->|)?\s*$/
  
  # Any error that occurs when parsing a source file
  class ParseException < Exception
  end
  
  # Regenerate delimits page components ("sections") using special HTML comments. 
  # The comment lines may - 1. start a comment, 2. end a comment, 
  # 3. be a self-contained comment line (in which case the self-contained comment may a) start  or b) end a page component, 
  #   or c) be a page component in itself.
  # The components of a Regenerate comment line are defined by the regex COMMENT_LINE_REGEX, and 
  # are identified as follows:
  # * "<!--" Comment start
  # * "[" Section start
  # * Ruby instance variable name (identifier starting with "@"), or, 
  #     a special section name (currently must be one of "ruby" or "class")
  # * "]" Section end
  # * "-->" Comment end
  # To be identified as a Regenerate comment line, a line must contain at least one of a
  # comment start and a comment end, and at least one of a section start and a section end.
  
  # An object which matches the regex used to identify Regenerate comment line commands
  # (Note, however, a parsed line may match the regex, but if it doesn't have at least one of a comment
  # start or a comment end and at least one of a section start or a section end, it will be assumed
  # that it is a line which was not intended to be parsed as a Regenerate command.)
  class ParsedRegenerateCommentLine
    
    attr_reader :line             # The full text line matched against
    attr_reader :isInstanceVar    # Is there an associated page object instance variable?
    attr_reader :hasCommentStart  # Does this command include the start of an HTML comment?
    attr_reader :hasCommentEnd    # Does this command include the end of an HTML comment?
    attr_reader :sectionStart     # Does this command include a section start indicator, i.e. "[" ?
    attr_reader :sectionEnd       # Does this command include a section start indicator, i.e. "]" ?
    attr_reader :isEmptySection   # Does this represent an empty section, because it starts and ends the same section?
    attr_reader :name             # The instance variable name (@something) or special command name ("ruby" or "class")
    attr_reader :value            # The optional value associated with a special command
    
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
    
    # Reconstruct a line which would re-parse the same (but possibly with reduced whitespace)
    def to_s
      "#{@hasCommentStart ? "<!-- ":""}#{@sectionStart ? "[ ":""}#{@isInstanceVar ? "@ ":""}#{@name.inspect}#{@value ? " "+@value:""}#{@sectionEnd ? " ]":""}#{@hasCommentEnd ? " -->":""}"
    end
    
    # Is this line recognised as a Regenerate comment line command?
    def isRegenerateCommentLine
      return (@hasCommentStart || @hasCommentEnd) && (@sectionStart || @sectionEnd)
    end
    
    # Does this command start a Ruby page component (because it has special command name "ruby")?
    def isRuby
      !@isInstanceVar && @name == "ruby"
    end
    
    # The name of the associated instance variable (assuming there is one)
    def instanceVarName
      return @name
    end
    
    # Raise a parse exception due to an error within this command line
    def raiseParseException(message)
      raise ParseException.new("Error parsing line #{@line.inspect}: #{message}")
    end
    
    # only call this method if isRegenerateCommentLine returns true - in other words, if it looks like
    # it was intended to be a Regenerate comment line command, check that it is valid.
    def checkIsValid
      # The "name" value has to be an instance variable name or "ruby" or "class"
      if !@isInstanceVar and !["ruby", "class"].include?(@name)
        raiseParseException("Unknown section name #{@name.inspect}")
      end
      # An empty section has to be a self-contained comment line
      if @isEmptySection and (!@hasCommentStart && !@hasCommentEnd)
        raiseParseException("Empty section, but is not a closed comment")
      end
      # If it's not a section start, it has to be a section end, so there has to be a comment end
      if !@sectionStart && !@hasCommentEnd
        raiseParseException("End of section in comment start")
      end
      # If it's not a section end, it has to be a section start, so there has to be a comment start
      if !@sectionEnd && !@hasCommentStart
        raiseParseException("Start of section in comment end")
      end
      # Empty Ruby page components aren't allowed.
      if (@sectionStart && @sectionEnd) && isRuby
        raiseParseException("Empty ruby section")
      end
    end
    
  end
  
  # When running with "checkNoChanges" flag, raise this error if a change is observed
  class UnexpectedChangeError < Exception
  end

  # A web page which is read from a source file and regenerated to an output file (which
  # may be the same as the source file)
  class WebPage
    
    include Regenerate::Utils
    
    attr_reader :fileName # The absolute name of the source file
    
    def initialize(fileName)
      @fileName = fileName
      @components = []
      @currentComponent = nil
      @componentInstanceVariables = {}
      initializePageObject(PageObject.new)  # default, can be overridden by SetPageObjectClass
      @pageObjectClassNameSpecified = nil # remember name if we have specified a page object class to override the default
      @rubyComponents = []
      readFileLines
    end

    # initialise the "page object", which is the object that "owns" the defined instance variables, 
    # and the object in whose context the Ruby components are evaluated
    # Three special instance variable values are set - @fileName, @baseDir, @baseFileName, 
    # so that they can be accessed, if necessary, by Ruby code in the Ruby code components.
    # (if this is called a second time, it overrides whatever was set the first time)
    # Notes on special instance variables -
    #  @fileName and @baseDir are the absolute paths of the source file and it's containing directory.
    #  They would be used in Ruby code that looked for other files with names or locations relative to these two.
    #  They would generally not be expected to appear in the output content.
    #  @baseFileName is the name of the file without any directory path components. In some cases it might be 
    #  used within output content.
    def initializePageObject(pageObject)
      @pageObject = pageObject
      setPageObjectInstanceVar("@fileName", @fileName)
      setPageObjectInstanceVar("@baseDir", File.dirname(@fileName))
      setPageObjectInstanceVar("@baseFileName", File.basename(@fileName))
      @initialInstanceVariables = Set.new(@pageObject.instance_variables)
    end
    
    # Get the value of an instance variable of the page object
    def getPageObjectInstanceVar(varName)
      @pageObject.instance_variable_get(varName)
    end
    
    # Set the value of an instance variable of the page object
    def setPageObjectInstanceVar(varName, value)
      puts " setPageObjectInstanceVar, #{varName} = #{value.inspect}"
      @pageObject.instance_variable_set(varName, value)
    end
    
    # Add a Ruby page component to this web page (so that later on it will be executed)
    def addRubyComponent(rubyComponent)
      @rubyComponents << rubyComponent
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
      if @pageObjectClassNameSpecified
        raise ParseException("Page object class name specified more than once")
      end
      @pageObjectClassNameSpecified = className
      pageObjectClass = classFromString(className)
      initializePageObject(pageObjectClass.new)
    end
    
    # Process a line of source text that has been identified as a Regenerate start and/or end of comment line
    def processCommandLine(parsedCommandLine, lineNumber)
      #puts "command: #{parsedCommandLine}"
      if @currentComponent && (@currentComponent.is_a? StaticHtml) # finish any current static HTML component
        @currentComponent.finishText
        @currentComponent = nil
      end
      if @currentComponent # we are in a page component other than a static HTML component
        if parsedCommandLine.sectionStart # we have already started, so we cannot start again
          raise ParseException.new("Unexpected section start #{parsedCommandLine} inside component")
        end
        @currentComponent.processEndComment(parsedCommandLine) # so, command must be a command to end the page component
        @currentComponent = nil
      else # not in any page component, so we need to start a new one
        if !parsedCommandLine.sectionStart # if it's an end command, error, because there is nothing to end
          raise ParseException.new("Unexpected section end #{parsedCommandLine}, outside of component")
        end
        if parsedCommandLine.isInstanceVar # it's a page component that defines an instance variable value
          if parsedCommandLine.hasCommentEnd # the value will be an HTML value
            startNewComponent(HtmlVariable.new, parsedCommandLine)
          else # the value will be an HTML-commented value
            startNewComponent(CommentVariable.new, parsedCommandLine)
          end
        else # not an instance var, so it must be a special command
          if parsedCommandLine.name == "ruby" # Ruby page component containing Ruby that will be executed in the 
                                              # context of the page object
            startNewComponent(RubyCode.new(lineNumber+1), parsedCommandLine)
          elsif parsedCommandLine.name == "class" # Specify Ruby class for the page object
            startNewComponent(SetPageObjectClass.new(parsedCommandLine.value), parsedCommandLine)
          else # not a known special command
            raise ParseException.new("Unknown section type #{parsedCommandLine.name.inspect}")
          end
        end
        if @currentComponent.finished # Did the processing cause the current page component to be finished?
          @currentComponent = nil # clear the current component
        end
      end
      
    end
    
    # Finish the current page component after we are at the end of the source file
    # Anything other than static HTML should be explicitly finished, and if it isn't finished, raise an error.
    def finishAtEndOfSourceFile
      if @currentComponent
        if @currentComponent.is_a? StaticHtml
          @currentComponent.finishText
          @currentComponent = nil
        else
          raise ParseException.new("Unfinished last component at end of file")
        end
      end
    end
    
    # Report the difference between two strings (that should be the same)
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
    
    # Check that a newly created output file has the same contents as another (backup) file containing the old contents
    # If it has changed, actually reset the new file to have ".new" at the end of its name, 
    # and rename the backup file to be the output file (in effect reverting the newly written output).
    def checkAndEnsureOutputFileUnchanged(outFile, oldFile)
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
    
    # Write the output of the page components to the output file (optionally checking that 
    # there are no differences between the new output and the existing output.
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
        checkAndEnsureOutputFileUnchanged(outFile, backupFileName)
      end
    end
    
    # Read in and parse lines from source file
    def readFileLines
      puts "Opening #{@fileName} ..."
      lineNumber = 0
      File.open(@fileName).each_line do |line|
        line.chomp!
        lineNumber += 1 # track line numbers for when Ruby code needs to be executed (i.e. to populate stack traces)
        #puts "line #{lineNumber}: #{line}"
        commentLineMatch = COMMENT_LINE_REGEX.match(line)
        if commentLineMatch # it matches the Regenerate command line regex (but might not actually be a command ...)
          parsedCommandLine = ParsedRegenerateCommentLine.new(line, commentLineMatch)
          #puts "parsedCommandLine = #{parsedCommandLine}"
          if parsedCommandLine.isRegenerateCommentLine # if it is a Regenerate command line
            parsedCommandLine.checkIsValid # check it is valid, and then, 
            processCommandLine(parsedCommandLine, lineNumber) # process the command line
          else
            processTextLine(line, lineNumber) # process a text line which is not a Regenerate command line
          end
        else
          processTextLine(line, lineNumber) # process a text line which is not a Regenerate command line
        end
      end
      # After processing all source lines, the only unfinished page component permitted is a static HTML component.
      finishAtEndOfSourceFile
      #puts "Finished reading #{@fileName}."
    end
    
    # Regenerate the source file (in-place)
    def regenerate
      executeRubyComponents
      writeRegeneratedFile(@fileName)
      #display
    end
    
    # Regenerate from the source file into the output file
    def regenerateToOutputFile(outFile, checkNoChanges = false)
      executeRubyComponents
      writeRegeneratedFile(outFile, checkNoChanges)
    end
    
    # Execute the Ruby components which consist of Ruby code to be evaluated in the context of the page object
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

  # The Ruby object contained within a web page. Instance variables defined in the HTML
  # belong to this object, and Ruby code defined in the page is executed in the context of this object.
  # This class is the base class for classes that define particular types of web pages
  class PageObject
    include Regenerate::Utils
    
    # Method to render an ERB template file in the context of this object
    def erb(templateFileName)
      @binding = binding
      File.open(relative_path(templateFileName), "r") do |input|
        templateText = input.read
        template = ERB.new(templateText, nil, nil)
        template.filename = templateFileName
        result = template.result(@binding)
      end
    end

    # Method to render an ERB template (defined in-line) in the context of this object
    def erbFromString(templateString)
      @binding = binding
      template = ERB.new(templateString, nil, nil)
      template.result(@binding)
    end
    
    # Calculate absolute path given path relative to the directory containing the source file for the web page
    def relative_path(path)
      File.expand_path(File.join(@baseDir, path.to_str))
    end

    # Require a Ruby file given a path relative to the web page source file.
    def require_relative(path)
      require relative_path(path)
    end

    # Save some of the page object's instance variable values to a file as JSON
    # This method depends on the following defined in the actual page object class:
    # * propertiesToSave instance method, to return an array of symbols
    # * propertiesFileName class method, to return name of properties file as a function of the web page source file name
    #  (propertiesFileName is a class method, because it needs to be invoked by other code that _reads_ the properties
    #   file when the page object itself does not exist)
    # Example of useage: an index file for a blog needs to read properties of each blog page, 
    # where the blog page objects have saved their details into the individual property files.
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
