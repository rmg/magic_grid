source "http://rubygems.org"

# Declare your gem's dependencies in magic_grid.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

#s.add_development_dependency "sqlite3"
platforms :ruby do
  gem 'sqlite3'
end
platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end

#  s.add_development_dependency "yard"
#  s.add_development_dependency "redcarpet"
unless ENV['TRAVIS']
  gem 'yard'
  gem 'redcarpet'
end

# jquery-rails is used by the dummy application
gem "jquery-rails"

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'
