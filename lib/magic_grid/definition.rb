require 'will_paginate/view_helpers/action_view'

module MagicGrid
  class Definition
    include WillPaginate::ActionView
    attr_accessor :columns, :collection, :magic_id, :options, :params, :accepted,
      :current_sort_col, :current_order, :default_order

    DEFAULTS = {
      :classes => [],
      :top_pager => false,
      :bottom_pager => true,
      :remote => false,
      :per_page => 30,
      :searchable => [],
      :min_search_length => 3,
      :id => false,
      :searcher => false,
      :needs_searcher => false,
      :live_search => true,
      :listeners => {},
      :default_col => 0,
      :default_order => :asc,
      :empty_header => false,
      :empty_footer => false,
      :if_empty => "No results found.",
    }

    def initialize(cols_or_opts, collection = nil, params = {}, opts = {})
      if cols_or_opts.is_a? Hash
        @options = DEFAULTS.merge(cols_or_opts.reject {|k| k == :cols})
        @columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        @options = DEFAULTS.merge opts
        @columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a Hash or an Array"
      end
      @default_order = @options[:default_order]
      @params = params
      @collection = collection
      if @collection.respond_to? :table
        table_name = @collection.quoted_table_name
        table_columns = @collection.table.columns.map {|c| c.name}
      else
        table_name = nil
        table_columns = @columns.each_index.to_a
      end
      i = 0
      hash = []
      @columns.map! do |c|
        if c.is_a? Symbol
          c = {:col => c}
        elsif c.is_a? String
          c = {:label => c}
        end
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
        @magic_id << @collection.to_sql.hash.abs.to_s(36) if @collection.respond_to? :to_sql
      end
      if not @options[:searcher] and not @options[:searchable].empty?
        @options[:needs_searcher] = true
        @options[:searcher] = param_key(:searcher)
      end
      @current_sort_col = sort_col_i = param(:col, @options[:default_col]).to_i
      if @collection.respond_to? :order and @columns.count > sort_col_i and @columns[sort_col_i].has_key? :sql
        sort_col = @columns[sort_col_i][:sql]
        @current_order = order(param(:order, @default_order))
        sort_dir = order_sql(@current_order)
        @collection = @collection.order("#{sort_col} #{sort_dir}")
      end
      @accepted = [:action, :controller, param_key(:page)]
      @accepted << param_key(:q) unless @options[:searchable].empty?
      @accepted << @options[:listeners].values #.map {|k| param_key k }
      if @collection.respond_to? :where
        @options[:listeners].each_pair do |key, value|
          if @params[value] and not @params[value].empty?
            @collection = @collection.where(key => @params[value])
          end
        end
        if param(:q) and not @options[:searchable].empty?
          search_cols = @options[:searchable].map  do |searchable|
            case searchable
            when Symbol
              known = @columns.find {|col| col[:col] == searchable}
              if known
                known[:sql]
              else
                "#{table_name}.#{searchable.to_s}"
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
            clauses = search_cols.map {|c| c << " LIKE :search" }.join(" OR ")
            @collection = @collection.where(clauses, {:search => "%#{param(:q)}%"})
          end
        end
      end
      if @options[:per_page]
        @collection = @collection.paginate(:page => param(:page, 1),
                                           :per_page => @options[:per_page])
      end
    end

    def param_key(key)
      "#{@magic_id}_#{key}".to_sym
    end

    def param(key, default=nil)
      @params.fetch(param_key(key), default)
    end

    def order(something)
      case something
      when 1, "1", :desc, :DESC, "desc", "DESC"
        1
      #when 0, "0", :asc, :ASC, "asc", "ASC"
      #  0
      else
        0
      end
    end

    def order_sql(something)
      ["ASC", "DESC"][order(something)]
    end
  end
end
