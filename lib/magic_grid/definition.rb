require 'will_paginate/view_helpers/action_view'

module MagicGrid
  class Definition
    include WillPaginate::ActionView
    attr_accessor :columns, :collection, :magic_id, :options, :params

    DEFAULTS = {
      :classes => [],
      :top_pager => true,
      :bottom_pager => false,
      :ajax => false,
      :per_page => 30,
      :searchable => [],
      :id => false,
      :searcher => false,
      :needs_searcher => false,
      :live_search => true,
    }

    def initialize(cols_or_opts, collection = nil, params = {}, opts = {})
      Rails.logger.debug "#{self.class}( #{collection.class} )"
      if cols_or_opts.is_a? Hash
        @options = DEFAULTS.merge(cols_or_opts.reject {|k| k == :cols})
        @columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        @options = DEFAULTS.merge opts
        @columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a Hash or an Array"
      end
      @params = params
      @collection = collection
      if @collection.respond_to? :table
        table_name = @collection.quoted_table_name
        table_columns = @collection.table.columns.map {|c| c.name}
      else
        table_name = nil
        table_columns = @columns.each_index.to_a
      end
      if not @options[:searcher] and not @options[:searchable].empty?
        @options[:needs_searcher] = true
        @options[:searcher] = param_key(:searcher)
      end
      i = 0
      hash = []
      @columns.map! do |c|
        c = {:col => c} if c.is_a? String or c.is_a? Symbol
        c[:id] = i
        i += 1
        if c.key?(:col) and c[:col].is_a? Symbol and table_columns.include? c[:col]
          c[:sql] = "#{table_name}.#{c[:col].to_s}"
        end
        c[:label] = c[:col].to_s.titleize if not c.key? :label
        hash << c[:label]
        c
      end
      if @options[:id]
        @magic_id = @options[:id]
      else
        @magic_id = hash.join.hash.abs.to_s(36)
        @magic_id += @collection.to_sql.hash.abs.to_s(36) if @collection.respond_to? :to_sql
      end
      sort_col_i = param(:col, opts.fetch(:default_col, 0)).to_i
      if @collection.respond_to? :order and @columns.count > sort_col_i and @columns[sort_col_i].has_key? :sql
        sort_col = @columns[sort_col_i][:sql]
        sort_dir_i = param(:order, opts.fetch(:default_order, 0)).to_i
        sort_dir = ['ASC', 'DESC'][sort_dir_i == 0 ? 0 : 1]
        @collection = @collection.order("#{sort_col} #{sort_dir}")
      end
      if @collection.respond_to? :where and param(:q) and not @options[:searchable].empty?
        search_cols = @options[:searchable].map  do |searchable|
          case searchable
          when Symbol
            known = @columns.find {|col| col[:col] == searchable}
            if known
              known[:sql]
            else
              "#{table_name}.#{col[:col].to_s}"
            end
          when Integer
            @columns[searchable][:sql]
          when String
            searchable
          else
            raise "Searchable must be identifiable"
          end
        end
        unless search_cols.empty?
          clauses = search_cols.map {|c| c + " LIKE :search" }.join(" OR ")
          @collection = @collection.where(clauses, {:search => "%#{param(:q)}%"})
        end
      end
      @collection = @collection.paginate(:page => param(:page, 1),
                                         :per_page => @options[:per_page])
    end

    def param_key(key)
      "#{@magic_id}_#{key}".to_sym
    end

    def param(key, default=nil)
      @params.fetch(param_key(key), default)
    end
  end
end
