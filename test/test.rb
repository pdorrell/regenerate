require 'regenerate/site-regenerator'

$dir = File.dirname(__FILE__)

for path in Regenerate::PathAndParents.new($dir) do
  puts " path = #{path.inspect}"
end


