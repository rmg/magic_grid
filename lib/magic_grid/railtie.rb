require 'magic_grid'
require 'will_paginate/array'

module MagicGrid
  class Railtie < Rails::Railtie
    initializer "magic_grid" do |app|
      ActiveSupport.on_load :action_view do
        require 'magic_grid/magic_grid_helpers'
      end
    end
  end
end
