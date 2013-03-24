require 'magic_grid/definition'
require 'magic_grid/order'

module MagicGrid
  class HtmlGrid
    attr_reader :view, :grid
    private :view, :grid

    def initialize(grid_definition, view, controller = nil)
      @grid = grid_definition
      @spinner_drawn = false
      @view ||= view
      @current_url = controller && controller.request.fullpath
    end

    def render(&row_renderer)
      @row_renderer = row_renderer || method(:grid_row)
      table_options = {
        :class => "magic_grid #{grid.options[:class]}",
        :id    => grid.magic_id,
        :data  => {
          :searcher             => grid.searcher,
          :current              => @current_url,
          :live_search          => grid.options[:live_search],
          :listeners            => grid.options[:listeners],
          :remote               => grid.options[:remote],
          :default_ajax_handler => grid.options[:default_ajax_handler],
          :params               => grid.base_params,
        }.reject {|_,v| v.nil? }
      }
      table(table_options)
    end

    def table(options)
      view.content_tag('table', options) do
        view.content_tag('thead', :data => {:params => grid.base_params}, &method(:magic_grid_head)) +
        view.content_tag('tbody', :class => "ui-widget-content", &method(:magic_rows)) +
        view.content_tag('tfoot', &method(:magic_grid_foot))
      end
    end

    def render_spinner
      unless @spinner_drawn
        @spinner_drawn = true
        view.tag('span',
                  :id => (grid.magic_id.to_s + "_spinner"),
                  :class => "magic_grid_spinner")
      end
    end

    def magic_grid_head
      thead = []
      if grid.needs_searcher?
        thead << searcher_block
      end
      if grid.options[:per_page] and grid.options[:top_pager]
        thead << magic_pager_block(true)
      end
      if thead.empty? and not grid.options[:collapse_emtpy_header]
        thead << filler_block(&method(:render_spinner))
      end
      thead << magic_column_headers
      thead.join.html_safe
    end

    def magic_grid_foot
      if grid.options[:per_page] and grid.options[:bottom_pager]
        magic_pager_block
      elsif not grid.options[:collapse_emtpy_footer]
        filler_block
      end
    end

    def filler_block(&block)
      view.content_tag 'tr' do
        view.content_tag('td', nil,
                          :class => 'full-width ui-widget-header',
                          :colspan => grid.columns.count,
                          &block)
      end
    end

    def magic_column_headers
      view.content_tag 'tr' do
        grid.columns.reduce(''.html_safe) do |acc, col|
          classes = ['ui-state-default'] << col.html_classes
          acc <<
          if col.sortable?
            sortable_header(col)
          else
            view.content_tag 'th', col.label.html_safe, :class => classes.join(' ')
          end
        end
      end
    end

    def magic_rows
      rows = grid.collection.map(&@row_renderer)
      if rows.empty?
        render_empty_collection(grid.options[:if_empty]).html_safe
      else
        rows.join.html_safe
      end
    end

    def render_empty_collection(fallback)
      if fallback
        view.content_tag 'tr' do
          view.content_tag('td', :colspan => grid.columns.count,
                            :class => 'if-empty') do
            if fallback.respond_to? :call
              fallback.call(grid).to_s
            else
              fallback
            end
          end
        end
      end
    end

    def grid_row(record)
      view.content_tag 'tr', :class => view.cycle('odd', 'even') do
        grid.columns.map { |c| grid_cell(c, record) }.join.html_safe
      end
    end

    def grid_cell(column, record)
      view.content_tag('td', :class => column.html_classes) do
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

    def order_icon(order = Order::Unordered)
      view.content_tag 'span', '', :class => "ui-icon #{order.icon_class}"
    end

    def column_link_params(col)
      id = col.id
      my_params = grid.base_params.merge(grid.param_key(:col) => id)
      params = HashWithIndifferentAccess.new(my_params)
      if id.to_s == grid.current_sort_col.to_s
        params[grid.param_key(:order)] = grid.current_order.reverse.to_param
      else
        params.delete(grid.param_key(:order))
      end
      params
    end

    def sortable_header(col)
      id = col.id
      label = col.label || id.titleize
      classes = ['sorter ui-state-default'] << col.html_classes
      params = column_link_params(col)
      if id.to_s == grid.current_sort_col.to_s
        order = grid.current_order
        classes << "sort-current" << order.css_class
      else
        order = Order::Unordered
      end
      view.content_tag 'th', :class => classes.join(' ') do
        view.link_to params, :remote => grid.options[:remote] do
          label.html_safe << order_icon(order)
        end
      end
    end

    def searcher_block
      view.content_tag('tr') do
        view.content_tag('td', :class => 'searcher full-width ui-widget-header',
                         :colspan => grid.columns.count) do
          searcher_input
        end
      end
    end

    def searcher_input
      searcher_data = {
        :min_length => grid.options[:min_search_length],
        :current    => grid.current_search,
      }
      searcher = view.label_tag(grid.searcher.to_sym,
                                grid.options[:searcher_label])
      searcher << view.search_field_tag(grid.searcher.to_sym,
                                        grid.param(:q),
                                        :placeholder => grid.options[:searcher_tooltip],
                                        :size        => grid.options[:searcher_size],
                                        :data        => searcher_data,
                                        :form        => "a form that doesn't exist")
      if grid.options[:search_button]
        searcher << view.button_tag(grid.options[:searcher_button],
                                    :class => 'magic-grid-search-button')
      end
      searcher << render_spinner
    end

    def magic_pager(collection, opts={})
      if view.respond_to? :will_paginate
        # WillPaginate
        view.will_paginate collection.collection, opts
      elsif view.respond_to? :paginate
        #Kaminari, or something else..
        view.paginate collection.collection, opts
      else
        ("<!-- page #{collection.current_page} of #{collection.total_pages} -->" +
         '<!-- INSTALL WillPaginate or Kaminari for a pager! -->').html_safe
      end
    end

    def magic_pager_block(spinner = false)
      view.content_tag('tr') do
        view.content_tag('td', :class => 'full-width ui-widget-header magic-pager',
                         :colspan => grid.columns.count) do
          pager = magic_pager(grid.magic_collection,
                              :param_name => grid.param_key(:page),
                              :params => grid.base_params)
          if spinner
            pager << render_spinner
          end
          pager
        end
      end
    end
  end
end
