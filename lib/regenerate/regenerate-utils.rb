module Regenerate
  
  module Utils
    
    def makeBackupFile(outFile)
      backupFileName = outFile+"~"
      if File.exists? backupFileName
        puts "Deleting existing backup file #{backupFileName} ..."
        File.delete (backupFileName)
      end
      if File.exists? outFile
        puts "Renaming file #{outFile} to #{backupFileName} ..."
        File.rename(outFile, backupFileName)
      end
      backupFileName
    end
    
    def ensureDirectoryExists(directoryName)
      if File.exist? directoryName
        if not File.directory? directoryName
          raise "Cannot create directory #{directoryName}, already exists as a non-directory file"
        end
      else
        puts "Creating missing directory #{directoryName} ..."
        FileUtils.makedirs(directoryName)
      end
    end
    
  end
    
end

