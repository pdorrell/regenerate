require 'pathname'
require 'fileutils'
require 'regenerate/regenerate-utils.rb'

module Regenerate
  
  # An object to iterate over a directory path and all its parent directories
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
  
  # The main object representing the static website source and output directories
  # where generation or regeneration will occur.
  # There are three types of generation/regeneration, depending on how it is invoked:
  # 1. Re-generate source file or files in-place
  # 2. Generate output file or files from source file or files
  # 3. Re-generate source file or files from output file or files (this is for when output files have been directly edited, 
  #                                                                and when it is possible to re-generate the source)
  class SiteRegenerator
    
    include Regenerate::Utils
    
    # an option to check for changes and throw an error before an existing output file is changed
    # (use this option to test that certain changes in your code _don't_ change the result for your website)
    attr_accessor :checkNoChanges 

    # Initialise giving base directory of project, and sub-directories for source and output
    # e.g. "/home/me/myproject", "src" and "output"
    def initialize(baseDir, sourceSubDir, outputSubDir)
      @baseDir = File.expand_path(baseDir)
      @sourceSubDir = sourceSubDir
      @outputSubDir = outputSubDir
      @sourceTypeSubDirs = {:source => @sourceSubDir, :output => @outputSubDir}
      @sourceTypeDirs = {:source => File.join(@baseDir, @sourceSubDir), 
        :output => File.join(@baseDir, @outputSubDir)}
      @oppositeSourceType = {:source => :output, :output => :source}
      @checkNoChanges = false
      puts "SiteRegenerator initialized, @baseDir = #{@baseDir.inspect}"
    end
    
    # files & directories starting with "_" are not output files (they are other helper files)
    def checkNotSourceOnly(pathComponents)
      for component in pathComponents do
        if component.start_with?("_")
          raise "Cannot regenerate source-only component #{pathComponents.join("/")}"
        end
      end
    end
    
    # Extensions for types of files to be generated/regenerated
    REGENERATE_EXTENSIONS = [".htm", ".html", ".xml"]
    
    SOURCE_EXTENSIONS = {".css" => [".scss", ".sass"]}
    
    # Copy a source file directly to an output file
    def copySrcToOutputFile(srcFile, outFile)
      makeBackupFile(outFile)
      FileUtils.cp(srcFile, outFile, :verbose => true)
    end
    
    # Generate an output file from a source file
    # (pathComponents represent the path from the root source directory to the actual file)
    def regenerateFileFromSource(srcFile, pathComponents)
      #puts "regenerateFileFromSource, srcFile = #{srcFile}, pathComponents = #{pathComponents.inspect}"
      subPath = pathComponents.join("/")
      outFile = File.join(@sourceTypeDirs[:output], subPath)
      #puts "  outFile = #{outFile}"
      ensureDirectoryExists(File.dirname(outFile))
      extension = File.extname(srcFile).downcase
      #puts "  extension = #{extension}"
      if REGENERATE_EXTENSIONS.include? extension
        WebPage.new(srcFile).regenerateToOutputFile(outFile, checkNoChanges)
      else
        copySrcToOutputFile(srcFile, outFile)
      end
    end
    
    # Generate a source file from an output file (if that can be done)
    def regenerateSourceFromOutput(outFile, pathComponents)
      #puts "regenerateSourceFromOutput, outFile = #{outFile}, pathComponents = #{pathComponents.inspect}"
      subPath = pathComponents.join("/")
      srcFile = File.join(@sourceTypeDirs[:source], subPath)
      #puts "  srcFile = #{srcFile}"
      ensureDirectoryExists(File.dirname(srcFile))
      extension = File.extname(outFile).downcase
      #puts "  extension = #{extension}"
      if REGENERATE_EXTENSIONS.include? extension
        raise "Regeneration from output not yet implemented."
      else
        okToCopyBack = true
        if SOURCE_EXTENSIONS.has_key? extension
          srcExtensions = SOURCE_EXTENSIONS[extension]
          srcNameWithoutExtension = srcFile.chomp(extension)
          possibleSrcFiles = srcExtensions.map{|srcExtension| srcNameWithoutExtension + srcExtension}
          for possibleSrcFile in possibleSrcFiles
            if File.exist? possibleSrcFile
              puts "NOT COPYING #{outFile} back to source because source file #{possibleSrcFile} exists"
              okToCopyBack = false
            end
          end
        end
        if okToCopyBack
          copySrcToOutputFile(outFile, srcFile)
        end
      end
    end
    
    # Regenerate (or generate) a file, either from source file or from output file
    def regenerateFile(srcFile, pathComponents, sourceType)
      #puts "regenerateFile, srcFile = #{srcFile}, sourceType = #{sourceType.inspect}"
      outFile = File.join(@sourceTypeDirs[@oppositeSourceType[sourceType]], File.join(pathComponents))
      #puts " outFile = #{outFile}"
      outFileDir = File.dirname(outFile)
      if !File.exists?(outFileDir)
        if sourceType == :output
          raise "Cannot create missing source directory #{outFileDir} - please do so manually if required"
        end
        ensureDirectoryExists(outFileDir)
      end
      if sourceType == :output
        regenerateSourceFromOutput(srcFile, pathComponents)
      elsif sourceType == :source
        regenerateFileFromSource(srcFile, pathComponents)
      end
    end
    
    # Regenerate (or generated) specified sub-directory or file in sub-directory
    # of source or output root directory (according to sourceType)
    def regenerateSubPath(pathComponents, sourceType)
      #puts "regenerateSubPath, pathComponents = #{pathComponents.inspect}, sourceType = #{sourceType.inspect}"
      srcPath = File.join(@sourceTypeDirs[sourceType], File.join(pathComponents))
      #puts " srcPath = #{srcPath}"
      if File.directory? (srcPath)
        for entry in Dir.entries(srcPath) do
          if ![".", ".."].include? entry
            if !entry.start_with?("_")
              regenerateSubPath(pathComponents + [entry], sourceType)
            end
          end
        end
      elsif File.file? (srcPath)
        regenerateFile(srcPath, pathComponents, sourceType)
      end
    end
    
    # Regenerate (or generate) from specified source file (according to whether the path is within
    # the source or output root directory).
    def regeneratePath(path)
      path = File.expand_path(path)
      #puts "SiteRegenerator.regeneratePath, path = #{path}"
      relativePath = Pathname.new(path).relative_path_from(Pathname.new(@baseDir))
      #puts " relativePath = #{relativePath}"
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
  
  # Searching upwards from the current directory, find a file ".regenerate.rb" in the root directory of the project
  def self.findRegenerateScript(path, fileName)
    puts "Find regenerate script ..."
    for dir in PathAndParents.new(path) do
      scriptFileName = File.join(dir, fileName)
      puts " looking for #{scriptFileName} ..."
      if File.exists?(scriptFileName)
        puts " FOUND #{scriptFileName}"
        return scriptFileName
      end
    end
    raise "File #{fileName} not found in #{path} or any or its parent directories"
  end
  
  # Run the ".regenerate.rb" script that is in the root directory of the project
  # (Note: .regenerate.rb is responsible for requiring Ruby scripts that define Ruby classes specific to the project, 
  #  for creating a SiteRegenerator instance, and for invoking the regeneratePath method
  #  on a file or directory name that has been set as the value of the "path" variable in the binding within which
  #  .regenerate.rb is being evaluated.)
  def self.regeneratePath(path)
    regenerateScriptFileName = findRegenerateScript(path, ".regenerate.rb")
    regenerateScript = File.read(regenerateScriptFileName)
    eval(regenerateScript, binding, regenerateScriptFileName, 1)
  end
end
