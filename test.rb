
path = File.dirname(__FILE__)
topLevel = false
while !topLevel do
  puts "path = #{path}"
  parentPath = File.dirname(path)
  topLevel = parentPath == path
  path = parentPath
end
