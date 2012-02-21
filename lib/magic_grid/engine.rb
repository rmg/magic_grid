module MagicGrid
  class Engine < ::Rails::Engine
    # Once in production, on every page view in development
    config.to_prepare do
      # no caching based on path like require does
      load 'magic_grid/helpers.rb'
    end
  end
end
