
module Rejenner
  
  # A component of static text which is not assigned to any variable, and which does not change
  class StaticHtml
    attr_reader :text
    def initialize(text)
      text
    end
    
    def output(showSource, showResult)
      text
    end
  end
  
  class RubyCode
    attr_reader :text
    def initialize(text)
      text
    end
    
    def output(showSource)
      if showSource
        "<!-- [ruby -->\n#{text}\n<!-- ruby] -->\n"
      else
        ""
      end
    end
  end
  
  # Base class for the text variable types
  class TextVariable
    attr_reader :varName, :text
    
    def initialize(varName, text)
      @varName = varName
      @text = text
    end
    
  end
  
  # HtmlVariable Can be both source and result
  class HtmlVariable < TextVariable
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
    def output(showSource)
      if showSource
          "<!-- [#{@varName}\n#{text}\n#{@varName}] -->\n"
      else
        ""
      end
    end
  end
  
end
