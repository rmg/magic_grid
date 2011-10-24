module ActionView
  module Helpers
    module MagicGridHelper
      class MagicGrid
        attr_accessor :columns, :collection, :magic_id, :options
        def initialize(cols_or_opts, collection = nil, params = {}, opts = {})
          if cols_or_opts.is_a? Hash
            @options = cols_or_opts.reject {|k| k == :cols}
            @columns = cols_or_opts.fetch(:cols, [])
          elsif cols_or_opts.is_a? Array
            @options = {}
            @columns = cols_or_opts
          else
            raise "I have no idea what that is, but it's not a Hash or an Array"
          end
          @collection = collection.page(params.fetch(:page, 1))
          table_columns = @collection.table.columns.map {|c| c.name}
          i = 0
          hash = []
          @columns.map! do |c|
            if c.is_a? String or c.is_a? Symbol
              c = {:col => c}
            end
            c[:id] = i
            i += 1
            if c[:col].is_a? Symbol and table_columns.include? c[:col]
              c[:sql] = "#{@collection.quoted_table_name}.#{c[:col].to_s}"
            end
            if not c.key? :label
              c[:label] = c[:col].to_s.titleize
            end
            hash << c[:label]
            c
          end
          @magic_id = hash.join.hash.abs.to_s(36) + @collection.to_sql.hash.abs.to_s(36)
          sort_col_i = params.fetch(:col, opts.fetch(:default_col, 0)).to_i
          if @columns[sort_col_i] and @columns[sort_col_i][:sql]
            sort_col = @columns[sort_col_i][:sql]
            sort_dir_i = params.fetch(:order, opts.fetch(:default_order, 0)).to_i
            sort_dir = ['ASC', 'DESC'][sort_dir_i == 0 ? 0 : 1]
            @collection = @collection.order("#{sort_col} #{sort_dir}")
          end
          Rails.logger.info("MagicGrid created!")
        end

        def self.normalize(collection, columns = [], options = {})
          if collection.is_a? MagicGrid
            collection
          elsif columns.is_a? MagicGrid
            columns
          elsif options.is_a? MagicGrid
            options
          else
            self.new(columns, collection, params, options)
          end
        end
      end

      def magic_collection(collection, cols, opts = {})
        MagicGrid.normalize(collection, cols, opts).collection
      end

      def magic_grid(collection = nil, cols = nil, opts = {}, &block)
        grid = MagicGrid.normalize(collection, cols, opts)
        content_tag 'table', :class => 'zebra wide thin-border ajaxed_pager', :id => "magic_#{grid.magic_id}" do
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
        grid = MagicGrid.normalize(collection, cols, opts)
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

      def magic_rows(cols, collection = nil)
        grid = MagicGrid.normalize(collection, cols)
        grid.collection.map do |row|
          if block_given?
            yield row
          else
            magic_row(row, grid)
          end
        end.join.html_safe
      end

      def magic_row(record, cols, collection = nil)
        cells = []
        grid = MagicGrid.normalize(collection, cols)
        grid.columns.each do |c|
          method = c[:to_s] || c[:col]
          cells << (record.respond_to?(method) ? record.send(method).to_s : '')
        end
        content_tag('tr', cells.map {|c| content_tag('td', c)}.join.html_safe)
      end

      def reverse_order(order)
        opp = order.to_i == 0 ? 1 : 0
        Rails.logger.info("CALL reverse_order( #{order} ) => #{opp}")
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
        Rails.logger.info "#{col.inspect}, #{classes.inspect}, #{my_params.inspect}, #{params.inspect}"
        content_tag 'th', link_to(label.html_safe, my_params), :class => classes.join(' ')
      end
    end
  end
end
