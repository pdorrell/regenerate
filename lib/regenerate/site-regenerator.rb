require 'pathname'

module Regenerate
  
  class PathAndParents
    def initialize(path)
      @path = path
    end
    
    def each
      currentPath = @path
      topLevel = false
      while !topLevel do
        yield currentPath
        parentPath = File.dirname(currentPath)
        topLevel = parentPath == currentPath
        currentPath = parentPath
      end
    end
  end
  
  class SiteRegenerator
    def initialize(baseDir, sourceSubDir, outputSubDir, 
                   fileConfigs)
      @baseDir = File.expand_path(baseDir)
      @sourceSubDir = sourceSubDir
      @outputSubDir = outputSubDir
      puts "SiteRegenerator, @baseDir = #{@baseDir.inspect}"
    end
    
    def checkNotSourceOnly(pathComponents)
      for component in pathComponents do
        if component.start_with?("_")
          raise "Cannot regenerate source-only component #{pathComponents.join("/")}"
        end
      end
    end
    
    def regenerateSubPath(pathComponents, sourceType)
      puts "regenerateSubPath, pathComponents = #{pathComponents.inspect}, sourceType = #{sourceType.inspect}"
    end
    
    def regeneratePath(path)
      path = File.expand_path(path)
      puts "SiteRegenerator.regeneratePath, path = #{path}"
      relativePath = Pathname.new(path).relative_path_from(Pathname.new(@baseDir))
      puts " relativePath = #{relativePath}"
      relativePathComponents = relativePath.to_s.split("/")
      puts " relativePathComponents = #{relativePathComponents.inspect}"
      subDir = relativePathComponents[0]
      relativeSubDirPathComponents = relativePathComponents[1..-1]
      checkNotSourceOnly(relativeSubDirPathComponents)
      if subDir == @sourceSubDir
        regenerateSubPath(relativeSubDirPathComponents, :source)
      elsif subDir == @outputSubDir
        regenerateSubPath(relativeSubDirPathComponents, :output)
      else
        raise "Path #{path} to regenerate is not contained in #{@sourceSubDir} (source) or #{@outputSubDir} (output) sub-directory of base dir #{@baseDir}"
      end
    end
    
  end
  
  def self.findRegenerateScript(path, fileName)
    for dir in PathAndParents.new(path) do
      scriptFileName = File.join(dir, fileName)
      puts " looking for #{scriptFileName} ..."
      if File.exists?(scriptFileName)
        return scriptFileName
      end
    end
    raise "File #{fileName} not found in #{path} or any or its parent directories"
  end
  
  def self.regeneratePath(path)
    regenerateScriptFileName = findRegenerateScript(path, ".regenerate.rb")
    regenerateScript = File.read(regenerateScriptFileName)
    eval(regenerateScript, binding, regenerateScriptFileName, 1)
  end
end
