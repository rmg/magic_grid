module MagicGrid
  class Engine < ::Rails::Engine
    # Once in production, on every page view in development
    config.to_prepare do |app|
      # no caching based on path like require does
      load 'magic_grid/helpers.rb'
    end

    initializer "magic_grid" do |app|
      # Provide some fallback translations that users can override
      app.config.i18n.load_path += Dir.glob(File.expand_path('../../locales/*.{rb,yml}', __FILE__))
    end

    initializer "Rails logger" do
      MagicGrid.logger = Rails.logger
    end
  end
end
