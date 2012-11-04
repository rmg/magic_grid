require 'magic_grid/definition'

module MagicGrid
  class HtmlGrid

    def initialize(grid_definition, view = nil, controller = nil)
      @grid = grid_definition
      @view ||= view
      @controller ||= controller
    end

    def render(controller, view, &block)
      @controller ||= controller
      @view ||= view
      grid_data = {
        searcher: @grid.searcher,
        current: controller.request.fullpath,
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
        thead + tbody(&block) + tfoot
      end
    end

    def thead
      @view.content_tag('thead', data: {params: @grid.base_params}) do
        magic_grid_head
      end
    end

    def tbody(&block)
      @view.content_tag('tbody', class: "ui-widget-content") do
        magic_rows &block
      end
    end

    def tfoot
      @view.content_tag('tfoot') do
        magic_grid_foot
      end
    end

    def magic_grid_head
      thead = ''.html_safe
      has_spinner = false
      spinner = @view.tag('span',
                    id: (@grid.magic_id.to_s + "_spinner"),
                    class: "magic_grid_spinner"
                   )
      spinner_generator = ->() {
        unless has_spinner
          has_spnner = true
          spinner
        end
      }
      if @grid.needs_searcher?
        thead << @view.content_tag('tr') do
          @view.content_tag('td', class: 'searcher full-width ui-widget-header',
                      colspan: @grid.columns.count) do
            search_bar(&spinner_generator)
          end
        end
      end
      if @grid.options[:per_page] and @grid.options[:top_pager]
        thead << magic_pager_block(&spinner_generator)
      end
      if thead.empty? and not @grid.options[:empty_header]
        thead = @view.content_tag 'tr' do
          @view.content_tag('td',
                      class: 'full-width ui-widget-header',
                      colspan: @grid.columns.count,
                      &spinner_generator)
        end
      end
      thead << magic_column_headers
    end

    def magic_grid_foot
      if @grid.options[:per_page] and @grid.options[:bottom_pager]
        magic_pager_block
      elsif not @grid.options[:empty_footer]
        @view.content_tag 'tr' do
          @view.content_tag('td', nil,
                            class: 'full-width ui-widget-header',
                            colspan: @grid.columns.count)
        end
      else
        ''.html_safe
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

    def magic_rows(&block)
      if_empty = @grid.options[:if_empty]
      rows = @grid.collection.map do |row|
        if block_given?
          "<!-- block: -->" << @view.capture(row, &block)
        else
          "<!-- magic row: -->" << magic_row(row)
        end
      end
      if rows.empty? and if_empty
        @view.content_tag 'tr' do
          @view.content_tag('td', colspan: @grid.columns.count,
                      class: 'if-empty') do
            if if_empty.respond_to? :call
              if_empty.call(@grid).to_s
            else
              if_empty
            end
          end
        end
      else
        rows.join.html_safe
      end
    end

    def magic_row(record)
      @view.content_tag 'tr', class: @view.cycle('odd', 'even') do
        @grid.columns.reduce(''.html_safe) do |acc, c|
          acc << @view.content_tag('td', class: c.html_classes) do
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
      my_params = HashWithIndifferentAccess.new(my_params)
      order = nil
      classes = ['sorter ui-state-default'] << col.html_classes
      current = id.to_s == @grid.current_sort_col.to_s
      if current
        order = @grid.current_order
        classes << "sort-current" << order_class(order)
        my_params[@grid.param_key(:order)] = reverse_order(order)
        label << order_icon(order)
      else
        my_params.delete @grid.param_key(:order) if my_params[@grid.param_key(:order)]
        label << order_icon()
      end
      my_params.delete(@grid.param_key(:order)) if my_params[@grid.param_key(:order)].to_i == default_sort_order.to_i
      @view.content_tag 'th', class: classes.join(' ') do
        @view.link_to label.html_safe, my_params, remote: @grid.options[:remote]
      end
    end

    def search_bar(&block)
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

    def magic_pager_block(&block)
      @view.content_tag('tr') do
        @view.content_tag('td', class: 'full-width ui-widget-header magic-pager',
                    colspan: @grid.columns.count) do
          pager = magic_pager(@grid.magic_collection,
                                param_name: @grid.param_key(:page),
                                params: @grid.base_params
                               )
          pager << @view.capture(&block) if block_given?
          pager
        end
      end
    end
  end
end
