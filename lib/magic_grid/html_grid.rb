require 'magic_grid/definition'

module MagicGrid
  class HtmlGrid

    def initialize(grid_definition, view, controller = nil)
      @grid = grid_definition
      @view ||= view
      if controller
        @current_url = controller.request.fullpath
      else
        @current_url = nil
      end
    end

    def render(&row_renderer)
      @spinner_drawn = false
      grid_data = {
        searcher: @grid.searcher,
        current: @current_url,
        live_search: @grid.options[:live_search],
        listeners: @grid.options[:listeners],
        remote: @grid.options[:remote],
        default_ajax_handler: @grid.options[:default_ajax_handler],
        params: @grid.base_params,
      }
      table_options = {
        class: (['magic_grid'] << @grid.options[:class]).join(' '),
        id: @grid.magic_id,
        data: grid_data.select {|_,v| v }
      }
      @view.content_tag('table', table_options) do
        thead + tbody(&row_renderer) + tfoot
      end
    end

    def thead
      @view.content_tag('thead', data: {params: @grid.base_params}) do
        magic_grid_head
      end
    end

    def tbody(&row_renderer)
      @view.content_tag('tbody', class: "ui-widget-content") do
        magic_rows &row_renderer
      end
    end

    def tfoot
      @view.content_tag('tfoot') do
        magic_grid_foot
      end
    end

    def spinner_generator
      unless @spinner_drawn
        @spinner_drawn = true
        @view.tag('span',
                  id: (@grid.magic_id.to_s + "_spinner"),
                  class: "magic_grid_spinner")
      end
    end

    def magic_grid_head
      spinner = self.method(:spinner_generator)
      thead = []
      if @grid.needs_searcher?
        thead << searcher_block(&spinner)
      end
      if @grid.options[:per_page] and @grid.options[:top_pager]
        thead << magic_pager_block(&spinner)
      end
      if thead.empty? and not @grid.options[:collapse_emtpy_header]
        thead << filler_block(&spinner)
      end
      thead << magic_column_headers
      thead.join.html_safe
    end

    def magic_grid_foot
      if @grid.options[:per_page] and @grid.options[:bottom_pager]
        magic_pager_block
      elsif not @grid.options[:collapse_emtpy_footer]
        filler_block
      end
    end

    def filler_block(content = nil, &block)
      @view.content_tag 'tr' do
        @view.content_tag('td', content,
                          class: 'full-width ui-widget-header',
                          colspan: @grid.columns.count,
                          &block)
      end
    end

    def magic_column_headers
      @view.content_tag 'tr' do
        @grid.columns.reduce(''.html_safe) do |acc, col|
          classes = ['ui-state-default'] << col.html_classes
          acc <<
          if col.sortable?
            sortable_header(col)
          else
            @view.content_tag 'th', col.label.html_safe, class: classes.join(' ')
          end
        end
      end
    end

    def magic_rows(&row_renderer)
      rows = @grid.collection.map { |row| grid_row(row, &row_renderer) }
      if rows.empty?
        rows << render_empty_collection(@grid.options[:if_empty])
      end
      rows.join.html_safe
    end

    def render_empty_collection(fallback)
      if fallback
        @view.content_tag 'tr' do
          @view.content_tag('td', colspan: @grid.columns.count,
                            class: 'if-empty') do
            if fallback.respond_to? :call
              fallback.call(@grid).to_s
            else
              fallback
            end
          end
        end
      end
    end

    def grid_row(record, &row_renderer)
      if row_renderer
        @view.capture(record, &row_renderer)
      else
        @view.content_tag 'tr', class: @view.cycle('odd', 'even') do
          @grid.columns.map { |c| grid_cell(c, record) }.join.html_safe
        end
      end
    end

    def grid_cell(column, record)
      @view.content_tag('td', class: column.html_classes) do
        method = column.reader
        if method.respond_to? :call
          method.call(record).to_s
        elsif record.respond_to? method
          record.send(method).to_s
        else
          ""
        end
      end
    end

    def unordered
      -1
    end

    def reverse_order(order)
      order.to_i == 0 ? 1 : 0
    end

    def order_icon(order = -1)
      @view.content_tag 'span', '', class: "ui-icon #{order_icon_class(order)}"
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

    def sortable_header(col)
      id = col.id
      label = col.label || id.titleize
      default_sort_order = @grid.order(@grid.default_order)
      my_params = @grid.base_params.merge({
        @grid.param_key(:col) => id,
      })
      column_link_params = HashWithIndifferentAccess.new(my_params)
      order = unordered
      classes = ['sorter ui-state-default'] << col.html_classes
      if id.to_s == @grid.current_sort_col.to_s
        order = @grid.current_order
        classes << "sort-current" << order_class(order)
        column_link_params[@grid.param_key(:order)] = reverse_order(order)
      else
        column_link_params.delete @grid.param_key(:order)
      end
      if column_link_params[@grid.param_key(:order)].to_i == default_sort_order.to_i
        column_link_params.delete(@grid.param_key(:order))
      end
      @view.content_tag 'th', class: classes.join(' ') do
        @view.link_to column_link_params, remote: @grid.options[:remote] do
          label.html_safe << order_icon(order)
        end
      end
    end

    def searcher_block(&spinner)
      @view.content_tag('tr') do
        @view.content_tag('td', class: 'searcher full-width ui-widget-header',
                    colspan: @grid.columns.count) do
          searcher_input(&spinner)
        end
      end
    end

    def searcher_input(&spinner)
      searcher_data = {
        min_length: @grid.options[:min_search_length],
        current: @grid.current_search || "",
      }
      searcher = @view.label_tag(@grid.searcher.to_sym,
                           @grid.options[:searcher_label])
      searcher << @view.search_field_tag(@grid.searcher.to_sym,
        @grid.param(:q),
        placeholder: @grid.options[:searcher_tooltip],
        size: @grid.options[:searcher_size],
        data: searcher_data,
        form: "a form that doesn't exist")
      if @grid.options[:search_button]
        searcher << @view.button_tag(@grid.options[:searcher_button],
          class: 'magic-grid-search-button')
      end
      searcher << yield if block_given?
      searcher
    end

    def magic_pager(collection, opts={})
      if @view.respond_to? :will_paginate
        # WillPaginate
        @view.will_paginate collection.collection, opts
      elsif @view.respond_to? :paginate
        #Kaminari, or something else..
        @view.paginate collection.collection, opts
      else
        ("<!-- page #{collection.current_page} of #{collection.total_pages} -->" +
         '<!-- INSTALL WillPaginate or Kaminari for a pager! -->').html_safe
      end
    end

    def magic_pager_block(&spinner)
      @view.content_tag('tr') do
        @view.content_tag('td', class: 'full-width ui-widget-header magic-pager',
                    colspan: @grid.columns.count) do
          pager = magic_pager(@grid.magic_collection,
                                param_name: @grid.param_key(:page),
                                params: @grid.base_params
                               )
          if spinner
            pager << @view.capture(&spinner)
          end
          pager
        end
      end
    end
  end
end
