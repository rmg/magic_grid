# require 'bundler'
# Bundler.setup

unless ENV['TRAVIS']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/test/'
  end
end

require 'magic_grid/logger'
require 'action_view'
require 'action_dispatch'
require 'test/unit'

begin
  require 'will_paginate'
  require 'will_paginate/array'
  require 'will_paginate/view_helpers/action_view'
  puts "Testing with WillPaginate"
  $will_paginate = true
rescue LoadError
  puts "skipping WillPaginate"
  $will_paginate = false
end

begin
  require 'kaminari'
  require 'kaminari/models/array_extension'
  puts "Testing with Kaminari"
  $kaminari = true
rescue LoadError
  puts "skipping Kaminari"
  $kaminari = false
end

class NullObject
  def method_missing(*args, &block) self; end
  def nil?; true; end
end

module ActionFaker
  attr_accessor :output_buffer
  def url_for(*args)
    "fake_url(#{args.inspect})".html_safe
  end

  def make_controller
    request = double.tap { |r|
      r.stub(:fullpath, "/foo?page=bar")
    }
    double.tap { |v|
      v.stub(:render)
      v.stub(:params) { {} }
      v.stub(:request) { request }
    }
  end
end

class TextSelector
  include ActionDispatch::Assertions::SelectorAssertions
  include Test::Unit::Assertions
  def initialize(text)
    @selected = HTML::Document.new(text).root.children
  end
end

RSpec::Matchers.define :match_select do |*expected|
  match do |actual|
    TextSelector.new(actual).assert_select(*expected)
  end
end

module FakeCollections
  def fake_connection
    double(:connection).tap do |c|
      c.stub(:quote_column_name) { |col| col.to_s }
    end
  end

  def fake_active_record_collection(table_name = 'some_table',
                                    columns = [:name, :description])
    columns = columns.map{|c| {:name => c} }
    (1..1000).to_a.tap do |c|
      c.stub(:connection => fake_connection)
      c.stub(:quoted_table_name => table_name)
      c.stub(:table_name => table_name)
      c.stub(:to_sql => "SELECT * FROM MONKEYS")
      c.stub(:table) {
              double.tap do |t|
                t.stub(:columns => columns)
              end
            }
      c.stub(:where) { c }
    end
  end
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.include ActionView::Helpers
  config.include WillPaginate::ActionView if $will_paginate
  config.include Kaminari::ActionViewExtension if $kaminari
  config.include ActionFaker
  config.include FakeCollections

  config.before do
    MagicGrid.logger = NullObject.new
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end
