module Regenerate
  
  def self.makeBackupFile(outFile)
    backupFileName = outFile+"~"
    if File.exists? backupFileName
      puts "Deleting existing backup file #{backupFileName} ..."
      File.delete (backupFileName)
    end
    if File.exists? outFile
      puts "Renaming file #{outFile} to #{backupFileName} ..."
      File.rename(outFile, backupFileName)
    end
  end
end

