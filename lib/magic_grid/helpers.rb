require 'magic_grid/definition'
require 'magic_grid/html_grid'

module MagicGrid
  module Helpers
    def normalize_magic(collection, columns = [], options = {})
      args_enum = [collection, columns, options].to_enum
      given_grid = args_enum.find {|e| e.is_a? MagicGrid::Definition }
      given_grid || MagicGrid::Definition.new(columns, collection, controller, options)
    end

    def magic_grid(collection = nil, cols = nil, opts = {}, &block)
      grid_def = normalize_magic(collection, cols, opts)
      html_grid = HtmlGrid.new grid_def, self, controller
      html_grid.render(&block)
    end

    ::ActionView::Base.send :include, self
  end
end
