Gem::Specification.new do |spec|
  spec.name              = "regenerate"
  spec.version           = "0.1.1"
  spec.platform          = Gem::Platform::RUBY
  spec.authors           = ["Philip Dorrell"]
  spec.email             = ["http://thinkinghard.com/email.html"]
  spec.homepage          = "https://github.com/pdorrell/regenerate"
  spec.summary           = "A static website generate/regenerator"
  spec.description       = "Use to regenerate to write a web page with embedded instance variable definitions and embedded ruby code which executes to regenerate the same web page (or generate to a separate output directory)."
  spec.rubyforge_project = spec.name

  spec.required_rubygems_version = ">= 1.3.6"
  
  # If you have runtime dependencies, add them here
  # spec.add_runtime_dependency "other", "~> 1.2"
  
  # If you have development dependencies, add them here
  # spec.add_development_dependency "another", "= 0.9"

  # The list of files to be contained in the gem
  spec.files = Dir['lib/**/*.rb']
  spec.files += ["LICENSE.txt", "Rakefile", "bin/regenerate"]

  spec.executables   = ["regenerate"]
  
  spec.require_paths = ['lib']
end
