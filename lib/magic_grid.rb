require 'action_view/helpers/magic_grid_helper'

module MagicGrid
end

ActionView::Helpers.send :include, ActionView::Helpers::MagicGridHelper
