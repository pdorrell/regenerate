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
    
    def regeneratePath(path)
      path = File.expand_path(path)
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
