require 'magic_grid/definition'

module MagicGrid
  module Helpers
    def normalize_magic(collection, columns = [], options = {})
      args_enum = [collection, columns, options].to_enum
      given_grid = args_enum.find {|e| e.is_a? MagicGrid::Definition }
      given_grid || MagicGrid::Definition.new(columns, collection, controller, options)
    end

    def magic_grid(collection = nil, cols = nil, opts = {}, &block)
      grid = normalize_magic(collection, cols, opts)
      base_params = grid.base_params
      grid_data = {
        searcher: grid.searcher,
        current: controller.request.fullpath,
        live_search: grid.options[:live_search],
        listeners: (grid.options[:listeners] unless grid.options[:listeners].empty?),
        remote: grid.options[:remote],
        default_ajax_handler: grid.options[:default_ajax_handler],
        params: base_params,
      }
      grid_data_without_nils = grid_data.select {|_,v| v }
      table_classes = ['magic_grid'] << grid.options[:class]
      content_tag('table',
                  class: table_classes.join(' '),
                  id: grid.magic_id,
                  data: grid_data_without_nils
                  ) do
        table = content_tag('thead', data: {params: base_params}) do
          magic_grid_head grid, base_params
        end
        table << content_tag('tbody', class: "ui-widget-content") do
          magic_rows(grid, &block)
        end
        table << content_tag('tfoot') do
          magic_grid_foot(grid, base_params)
        end
      end
    end

    def magic_grid_head(grid, base_params)
      thead = ''.html_safe
      has_spinner = false
      spinner = tag('span',
                    id: (grid.magic_id.to_s + "_spinner"),
                    class: "magic_grid_spinner"
                   )
      if grid.needs_searcher?
        thead << content_tag('tr') do
          content_tag('td', class: 'searcher full-width ui-widget-header',
                      colspan: grid.columns.count) do
            searcher = search_bar(grid)
            unless has_spinner
              has_spinner = true
              searcher << spinner
            end
            searcher
          end
        end
      end
      if grid.options[:per_page] and grid.options[:top_pager]
        thead << magic_pager(grid, base_params) do
          unless has_spinner
            has_spinner = true
            spinner
          end
        end
      end
      if thead.empty? and not grid.options[:empty_header]
        thead = content_tag 'tr' do
          content_tag('td', class: 'full-width ui-widget-header',
                      colspan: grid.columns.count) do
            unless has_spinner
              has_spnner = true
              spinner
            end
          end
        end
      end
      thead << magic_column_headers(grid)
    end

    def magic_grid_foot(grid, base_params)
      tfoot = ''.html_safe
      if grid.options[:per_page] and grid.options[:bottom_pager]
        tfoot << magic_pager(grid, base_params)
      end
      if tfoot.empty? and not grid.options[:empty_footer]
        tfoot = content_tag 'tr' do
          content_tag('td', nil, class: 'full-width ui-widget-header',
                      colspan: grid.columns.count)
        end
      end
      tfoot
    end

    def magic_column_headers(cols, collection = nil, opts = {})
      grid = normalize_magic(collection, cols, opts)
      content_tag 'tr' do
        grid.columns.reduce(''.html_safe) do |acc, col|
          classes = ['ui-state-default'] << col.html_classes
          acc <<
          if col.sortable?
            sortable_header(grid, col, opts)
          else
            content_tag 'th', col.label.html_safe, class: classes.join(' ')
          end
        end
      end
    end

    def magic_rows(cols, collection = nil, &block)
      grid = normalize_magic(collection, cols)
      if_empty = grid.options[:if_empty]
      rows = grid.collection.map do |row|
        if block_given?
          "<!-- block: -->" << capture(row, &block)
        else
          "<!-- magic row: -->" << magic_row(row, grid)
        end
      end
      if rows.empty? and if_empty
        content_tag 'tr' do
          content_tag('td', colspan: grid.columns.count,
                      class: 'if-empty') do
            if if_empty.respond_to? :call
              if_empty.call(grid).to_s
            else
              if_empty
            end
          end
        end
      else
        rows.join.html_safe
      end
    end

    def magic_row(record, cols, collection = nil)
      grid = normalize_magic(collection, cols)
      content_tag 'tr', class: cycle('odd', 'even') do
        grid.columns.reduce(''.html_safe) do |acc, c|
          acc << content_tag('td', class: c.html_classes) do
            method = c.reader
            if method.respond_to? :call
              method.call(record)
            elsif record.respond_to? method
              record.send(method)
            end.to_s
          end
        end
      end
    end

    def reverse_order(order)
      order.to_i == 0 ? 1 : 0
    end

    def order_icon(order = -1)
      content_tag 'span', '', class: "ui-icon #{order_icon_class(order)}"
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

    def sortable_header(grid, col, opts = {})
      id = col.id
      label = col.label || id.titleize
      default_sort_order = opts.fetch(:default_order, grid.order(grid.default_order))
      my_params = grid.base_params.merge({
        grid.param_key(:col) => id,
      })
      my_params = HashWithIndifferentAccess.new(my_params)
      order = nil
      classes = ['sorter ui-state-default'] << col.html_classes
      current = id.to_s == grid.current_sort_col.to_s
      if current
        order = grid.current_order
        classes << "sort-current" << order_class(order)
        my_params[grid.param_key(:order)] = reverse_order(order)
        label << order_icon(order)
      else
        my_params.delete grid.param_key(:order) if my_params[grid.param_key(:order)]
        label << order_icon()
      end
      my_params.delete(grid.param_key(:order)) if my_params[grid.param_key(:order)].to_i == default_sort_order.to_i
      content_tag 'th', class: classes.join(' ') do
        link_to label.html_safe, my_params, remote: grid.options[:remote]
      end
    end

    def search_bar(grid)
      searcher_data = {
        min_length: grid.options[:min_search_length],
        current: grid.current_search || "",
      }
      searcher = label_tag(grid.searcher.to_sym,
                           grid.options[:searcher_label])
      searcher << search_field_tag(grid.searcher.to_sym,
        grid.param(:q),
        placeholder: grid.options[:searcher_tooltip],
        size: grid.options[:searcher_size],
        data: searcher_data,
        form: "a form that doesn't exist")
      if grid.options[:search_button]
        searcher << button_tag(grid.options[:searcher_button],
          class: 'magic-grid-search-button')
      end
      searcher
    end

    def magic_paginate(collection, opts={})
      if respond_to? :will_paginate
        # WillPaginate
        will_paginate collection.collection, opts
      elsif respond_to? :paginate
        #Kaminari, or something else..
        paginate collection.collection, opts
      else
        ("<!-- page #{collection.current_page} of #{collection.total_pages} -->" +
         '<!-- INSTALL WillPaginate or Kaminari for a pager! -->').html_safe
      end
    end

    def magic_pager(grid, base_params, &block)
      content_tag('tr') do
        content_tag('td', class: 'full-width ui-widget-header magic-pager',
                    colspan: grid.columns.count) do
          pager = magic_paginate(grid.magic_collection,
                                param_name: grid.param_key(:page),
                                params: base_params
                               )
          pager << capture(&block) if block_given?
          pager
        end
      end
    end

    ::ActionView::Base.send :include, self
  end
end
