require 'magic_grid'
require 'will_paginate/array'

class MagicGrid
  class Railtie < Rails::Railtie
    initializer "magic_grid" do |app|
      ActiveSupport.on_load :action_view do
        require 'magic_grid/helpers'
      end
    end
  end
end
