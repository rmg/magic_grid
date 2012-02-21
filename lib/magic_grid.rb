module MagicGrid
  if ::Rails.version < "3.1"
    require 'magic_grid/railtie'
  else
    require 'magic_grid/engine'
  end
end
