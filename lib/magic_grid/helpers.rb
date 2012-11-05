require 'magic_grid/definition'
require 'magic_grid/html_grid'

module MagicGrid
  module Helpers
    def magic_grid(collection = nil, columns = nil, opts = {}, &block)
      grid_def = MagicGrid::Definition.new columns, collection, controller, opts
      html_grid = HtmlGrid.new grid_def, self, controller
      html_grid.render &block
    end

    ::ActionView::Base.send :include, self
  end
end
