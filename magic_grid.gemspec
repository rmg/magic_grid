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
  s.summary     = "Easy collection display grid with column sorting and pagination"
  s.description = <<-EOF
    Displays a collection (ActiveRelation or Array) wrapped in an html table with server
    side column sorting, filtering hooks, and search bar. Large collections can be
    paginated with either the will_paginate gem or kaminari gem if you use them, or a naive
    Enumerable based paginator (without pager links) if neither is present.
  EOF
  s.has_rdoc    = 'yard'

  s.files = Dir["lib/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["{spec,test}/**/*"] - Dir["test/dummy/tmp/**/*", "test/dummy/db/*.sqlite3", "test/dummy/log/*.log"]

  s.add_dependency "rails", ">= 3.1"
  s.add_dependency "jquery-rails" , ">= 1.0.17"

  s.add_development_dependency "rake", "~> 0.9.2"
  s.add_development_dependency "tarantula", "~> 0.4.0"
  s.add_development_dependency "rspec", "~> 2.11.0"
end
