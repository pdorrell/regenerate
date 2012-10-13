Gem::Specification.new do |s|
  s.name              = "regenerate"
  s.version           = "0.0.1"
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Philip Dorrell"]
  s.email             = ["http://www.1729.com/email.html"]
  s.homepage          = "https://github.com/pdorrell/regenerate"
  s.summary           = "A static website regenerator"
  s.description       = "Use to regenerate to write a web page with embedded instance variable definitions and embedded ruby code which executes to regenerate the same web page."
  s.rubyforge_project = s.name

  s.required_rubygems_version = ">= 1.3.6"
  
  # If you have runtime dependencies, add them here
  # s.add_runtime_dependency "other", "~> 1.2"
  
  # If you have development dependencies, add them here
  # s.add_development_dependency "another", "= 0.9"

  # The list of files to be contained in the gem
  spec.files = Dir['lib/**/*.rb']
  spec.files += ["LICENSE.txt", "Rakefile"]

  # s.executables   = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  
  s.require_paths = ['lib']
end
