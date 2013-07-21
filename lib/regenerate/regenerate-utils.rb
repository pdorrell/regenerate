module Regenerate
  
  module Utils
    
    # If an old version of an output file exists, rename it to same file with "~" at the end.
    # If that file (an earlier backup file) exists, delete it first.
    def makeBackupFile(outFile)
      backupFileName = outFile+"~"
      if File.exists? backupFileName
        puts "BACKUP: deleting existing backup file #{backupFileName} ..."
        File.delete (backupFileName)
      end
      if File.exists? outFile
        puts "BACKUP: renaming file #{outFile} to #{backupFileName} ..."
        File.rename(outFile, backupFileName)
      end
      backupFileName
    end
    
    # Cause a directory to be created if it does not already exist. 
    # Raise an error if it does not exist and it cannot be created.
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

