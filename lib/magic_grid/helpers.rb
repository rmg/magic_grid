require 'magic_grid/definition'
require 'will_paginate/array'

module MagicGrid
  module Helpers
    def normalize_magic(collection, columns = [], options = {})
      if collection.is_a? MagicGrid::Definition
        collection
      elsif columns.is_a? MagicGrid::Definition
        columns
      elsif options.is_a? MagicGrid::Definition
        options
      else
        MagicGrid::Definition.new(columns, collection, params, options)
      end
    end

    def magic_collection(collection, cols, opts = {})
      normalize_magic(collection, cols, opts).collection
    end

    def magic_grid(collection = nil, cols = nil, opts = {}, &block)
      grid = normalize_magic(collection, cols, opts)
      classes = ['magic_grid'] + grid.options[:classes]
      classes << 'ajaxed_pager' if grid.options[:ajax]
      classes << 'has-searcher' if grid.options[:searcher]
      content_tag('table',
                  :class => classes.join(' '),
                  :id => grid.magic_id,
                  :data => {
                    :searcher => grid.options[:searcher],
                    :current => url_for,
                    :live_search => grid.options[:live_search]
                  }) do
        table = content_tag 'thead' do
          thead = ''.html_safe
          if grid.options[:needs_searcher]
            thead += content_tag 'tr', :class => 'searcher' do
              content_tag 'th', {:colspan => grid.columns.count} do
                label_tag(grid.options[:searcher].to_sym, 'Search: ') +
                  search_field_tag(grid.options[:searcher].to_sym, grid.param(:q))
              end
            end
          end
          if grid.options[:top_pager]
            thead += content_tag 'tr', :class => 'pagination' do
              content_tag 'td', {:colspan => grid.columns.count} do
                will_paginate(grid.collection,
                              :class => "pagination apple_pagination",
                              :param_name => grid.param_key(:page)
                             )
              end
            end
          end
          thead += magic_headers(grid)
        end
        table += content_tag 'tbody' do
          magic_rows(grid, &block)
        end
        if grid.options[:bottom_pager]
          table += content_tag 'tfoot' do
            content_tag 'tr', :class => 'pagination' do
              content_tag 'td', {:colspan => grid.columns.count} do
                will_paginate(grid.collection,
                              :class => "pagination apple_pagination",
                              :param_name => grid.param_key(:page)
                             )
              end
            end
          end
        else
          table
        end
      end
    end

    def magic_headers(cols, collection = nil, opts = {})
      grid = normalize_magic(collection, cols, opts)
      headers = grid.columns.map do |col|
        if col.is_a? String
          "<th>#{col}</th>"
        elsif not col.key? :sql
          "<th>#{col[:label]}</th>"
        else
          sortable_header(grid, col[:id], col[:label], opts)
        end
      end
      content_tag 'tr', headers.join.html_safe
    end

    def magic_rows(cols, collection = nil, &block)
      grid = normalize_magic(collection, cols)
      grid.collection.map do |row|
        if block_given?
          "<!-- block: -->" + capture(row, &block)
        else
          "<!-- magic row: -->" + magic_row(row, grid)
        end
      end.join.html_safe
    end

    def magic_row(record, cols, collection = nil)
      grid = normalize_magic(collection, cols)
      content_tag 'tr', :class => cycle('odd', 'even') do
        grid.columns.map do |c|
          content_tag 'td' do
            method = c[:to_s] || c[:col]
            if method.respond_to? :call
              method.call(record)
            elsif record.respond_to? method
              record.send(method)
            end.to_s
          end
        end.join.html_safe
      end
    end

    def reverse_order(order)
      order.to_i == 0 ? 1 : 0
    end

    def order_icon(order = -1)
      content_tag 'span', '', :class => "ui-icon #{order_icon_class(order)}"
    end

    def order_icon_class(order = -1)
      case order.to_i
      when 0 then 'ui-icon-triangle-1-n'
      when 1 then 'ui-icon-triangle-1-s'
      else 'ui-icon-carat-2-n-s'
      end
    end

    def order_class(order = -1)
      case order.to_i
      when 0 then 'sort-asc'
      when 1 then 'sort-desc'
      else 'sort-none'
      end
    end

    def sortable_header(grid, col, label = nil, opts = {})
      label ||= col.titleize
      default_sort_order = opts.fetch(:default_order, 0)
      my_params = params.select do |k,v|
        [:action, :controller, grid.param_key(:page), grid.param_key(:q)].include? k.to_sym
      end
      my_params = my_params.merge({grid.param_key(:col) => col})
      my_params = HashWithIndifferentAccess.new(my_params)
      order = nil
      classes = ['sorter']
      current = grid.param(:col).to_s == my_params[grid.param_key(:col)].to_s
      if current
        order = grid.param(:order, default_sort_order)
        classes << "sort-current" << order_class(order)
        my_params[grid.param_key(:order)] = reverse_order(order)
        label += order_icon(order)
      else
        my_params.delete grid.param_key(:order) if my_params[grid.param_key(:order)]
        label += order_icon()
      end
      my_params.delete(grid.param_key(:order)) if my_params[grid.param_key(:order)].to_i == default_sort_order.to_i
      content_tag 'th', :class => classes.join(' ') do
        link_to label.html_safe, my_params
      end
    end

    ::ActionView::Base.send :include, self
  end
end
