
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
    def output(showSource, showResult)
      if showSource
        "<!-- [html/#{@varName} -->\n#{text}\n<!-- html/#{@varName}] -->\n"
      else
        text
      end
    end
  end
  
  # DerivedHtmlVariable Is always a result of other input data (the result can be discarded)
  class DerivedHtmlVariable < TextVariable
    def output(showSource, showResult)
      if showResult
        if showSource
          "<!-- [derivedHtml/#{@varName} -->\n#{text}\n<!-- derivedHtml/#{@varName}] -->\n"
        else
          text
        end
      else
        "<!-- [derivedHtml/#{@varName}] -->\n"
      end
    end
  end
  
  # SourceCommentVariable Is an input only
  class SourceCommentVariable
    def output(showSource, showResult)
      if showSource
          "<!-- [source/#{@varName}\n#{text}\source/#{@varName}] -->\n"
      else
        ""
      end
    end
  end
  
end
