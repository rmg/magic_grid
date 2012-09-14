require 'bundler'
Bundler.setup

require 'action_view'
require 'rails'

begin
  require 'will_paginate'
  require 'will_paginate/array'
  require 'will_paginate/view_helpers'
  puts "Testing with WillPaginate"
rescue LoadError
  puts "skipping WillPaginate"
end

begin
  require 'kaminari'
  require 'kaminari/models/array_extension'
  puts "Testing with Kaminari"
rescue LoadError
  puts "skipping Kaminari"
end

Rails.backtrace_cleaner.remove_silencers!

# I has a sad :-(
module Rails
  def logger.debug(*ignore) end
end

module ActionFaker
  def output_buffer=(o)
    @output_buffer = o
  end
  def output_buffer()
    @output_buffer
  end
  def url_for
    "fake_url"
  end
  def controller
    stub_controller = ActionController::Base.new
    def stub_controller.params(*ignored) {} end
    stub_controller
  end
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.include ActionView::Helpers
  config.include WillPaginate::ViewHelpers if Module.const_defined? :WillPaginate
  config.include Kaminari::ActionViewExtension if Module.const_defined? :Kaminari
  config.include ActionFaker

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end
