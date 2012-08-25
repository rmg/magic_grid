$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "magic_grid/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "magic_grid"
  s.version     = MagicGrid::VERSION
  s.authors     = ["Ryan Graham"]
  s.email       = ["r.m.graham@gmail.com"]
  s.homepage    = "https://github.com/rmg/magic_grid"
  s.summary     = "Simple collection displaying with pagination using will_paginate"
  s.description = "Simple collection displaying with pagination using will_paginate"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.1.0"
  s.add_dependency "will_paginate", "~> 3.0.0"
  s.add_dependency "jquery-rails" , ">= 1.0.17"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rake"
  s.add_development_dependency "tarantula"
  s.add_development_dependency "rspec"
end
