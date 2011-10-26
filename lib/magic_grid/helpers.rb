class MagicGrid
  module Helpers
    def normalize_magic(collection, columns = [], options = {})
      if collection.is_a? MagicGrid
        collection
      elsif columns.is_a? MagicGrid
        columns
      elsif options.is_a? MagicGrid
        options
      else
        MagicGrid.new(columns, collection, params, options)
      end
    end

    def magic_collection(collection, cols, opts = {})
      normalize_magic(collection, cols, opts).collection
    end

    def magic_grid(collection = nil, cols = nil, opts = {}, &block)
      grid = normalize_magic(collection, cols, opts)
      classes = ['magic_grid']
      classes << 'zebra' if grid.options[:striped]
      classes << 'wide' if grid.options[:wide]
      classes << 'ajaxed_pager' if grid.options[:ajax]
      content_tag 'table', :class => classes.join(' '), :id => "magic_#{grid.magic_id}" do
        table = content_tag 'thead' do
          thead = content_tag 'tr', :class => 'pagination' do
            content_tag 'td', {:colspan => grid.columns.count} do
              will_paginate grid.collection, :class => "pagination apple_pagination"
            end
          end
          thead += magic_headers(grid)
        end
        table += content_tag 'tbody' do
          magic_rows(grid, &block)
        end
      end
    end

    def magic_headers(cols, collection = nil, opts = {})
      grid = normalize_magic(collection, cols, opts)
      headers = grid.columns.each_index.map do |i|
        if grid.columns[i].is_a? String
          "<th>#{grid.columns[i]}</th>"
        elsif not grid.columns[i].key? :sql
          "<th>#{grid.columns[i][:label]}</th>"
        else
          sortable_header(i, grid.columns[i][:label], opts)
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
      cells = []
      grid = normalize_magic(collection, cols)
      grid.columns.each do |c|
        method = c[:to_s] || c[:col]
        cells << (record.respond_to?(method) ? record.send(method).to_s : '')
      end
      content_tag('tr', cells.map {|c| content_tag('td', c)}.join.html_safe)
    end

    def reverse_order(order)
      opp = order.to_i == 0 ? 1 : 0
      Rails.logger.debug "CALL reverse_order( #{order} ) => #{opp}"
      opp
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

    def sortable_header(col, label = nil, opts = {})
      label ||= col.titleize
      default_sort_order = opts.fetch(:default_order, 0)
      my_params = HashWithIndifferentAccess.new(params.select {|k,v| [:action, :controller, :page].include? k.to_sym }.merge({:col => col}))
      order = nil
      classes = []
      current = params[:col].to_s == my_params[:col].to_s
      if current
        order = params.fetch(:order, default_sort_order)
        classes << "sort-current" << order_class(order)
        my_params[:order] = reverse_order(order)
        label += order_icon(order)
      else
        my_params.delete :order if my_params[:order]
        label += order_icon()
      end
      my_params.delete(:order) if my_params[:order].to_i == default_sort_order.to_i
      Rails.logger.debug "#{col.inspect}, #{classes.inspect}, #{my_params.inspect}, #{params.inspect}"
      content_tag 'th', link_to(label.html_safe, my_params), :class => classes.join(' ')
    end

    ::ActionView::Base.send :include, self
  end
end
