#require 'will_paginate/view_helpers/action_view'

module MagicGrid
  class Definition
    #include WillPaginate::ActionView
    attr_accessor :columns, :collection, :magic_id, :options, :params,
      :current_sort_col, :current_order, :default_order

    DEFAULTS = {
      :class => [],
      :top_pager => false,
      :bottom_pager => true,
      :remote => false,
      :per_page => 30,
      :searchable => false,
      :search_method => :search,
      :min_search_length => 3,
      :id => false,
      :searcher => false,
      :needs_searcher => false,
      :live_search => false,
      :current_search => nil,
      :listeners => {},
      :listener_handler => nil,
      :default_col => 0,
      :default_order => :asc,
      :empty_header => false,
      :empty_footer => false,
      :post_filter => false,
      :collection_post_filter? => true,
      :default_ajax_handler => true,
      :search_button => false,
      :searcher_size => nil,
    }

    def self.runtime_defaults
      # run these lazily to catch any late I18n path changes
      DEFAULTS.merge(
        :if_empty => I18n.t("magic_grid.no_results").capitalize, # "No results found."
        :searcher_label => I18n.t("magic_grid.search.label").capitalize + ': ', # "Search: "
        :searcher_tooltip =>I18n.t("magic_grid.search.tooltip"), # "type.. + <return>"
        :searcher_button =>I18n.t("magic_grid.search.button").capitalize, # "Search"
      )
    end

    def initialize(cols_or_opts, collection = nil, controller = nil, opts = {})
      if cols_or_opts.is_a? Hash
        @options = self.class.runtime_defaults.merge(cols_or_opts.reject {|k| k == :cols})
        @columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        @options = self.class.runtime_defaults.merge opts
        @columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a Hash or an Array"
      end
      @default_order = @options[:default_order]
      @params = controller.try(:params) || {}
      @collection = collection
      begin
        #if @collection.respond_to? :table
        table_name = @collection.quoted_table_name
        table_columns = @collection.table.columns.map {|c| c.name}
      rescue
        Rails.logger.debug "Given collection doesn't respond to :table well"
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
        if c.key?(:col) and c[:col].is_a?(Symbol) and table_columns.include?(c[:col])
          c[:sql] = "#{table_name}.#{@collection.connection.quote_column_name(c[:col].to_s)}" unless c.key?(:sql)
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
      @current_sort_col = sort_col_i = param(:col, @options[:default_col]).to_i
      if @collection.respond_to?(:order) and @columns.count > sort_col_i and @columns[sort_col_i].has_key?(:sql)
        sort_col = @columns[sort_col_i][:sql]
        @current_order = order(param(:order, @default_order))
        sort_dir = order_sql(@current_order)
        @collection = @collection.order("#{sort_col} #{sort_dir}")
      else
        Rails.logger.debug "#{self.class.name}: Ignoring sorting on non-AR collection"
      end

      @options[:searchable] = [] if @options[:searchable] and not @options[:searchable].kind_of? Array

      if @collection.respond_to?(:where) or @options[:listener_handler].respond_to?(:call)
        if @options[:listener_handler].respond_to? :call
          @collection = @options[:listener_handler].call(@collection)
        else
          @options[:listeners].each_pair do |key, value|
            if @params[value] and not @params[value].to_s.empty?
              @collection = @collection.where(key => @params[value])
            end
          end
        end
      else
        unless @options[:listeners].empty?
          Rails.logger.warn "#{self.class.name}: Ignoring listener on dumb collection"
          @options[:listeners] = {}
        end
      end
      @options[:current_search] ||= param(:q)
      if (@collection.respond_to?(:where) or
          (@options[:search_method] and @collection.respond_to?(@options[:search_method])))
        if param(:q) and not param(:q).empty? and @options[:searchable]
          orig_collection = @collection
          begin
            @collection = @collection.__send__(@options[:search_method], param(:q))
          rescue
            Rails.logger.debug "Given collection doesn't respond to #{@options[:search_method]} well"
            @collection = orig_collection
            search_cols = @options[:searchable].map do |searchable|
              case searchable
              when Symbol
                known = @columns.find {|col| col[:col] == searchable}
                if known and known.key?(:sql)
                  known[:sql]
                else
                  "#{table_name}.#{@collection.connection.quote_column_name(searchable.to_s)}"
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
              begin
                clauses = search_cols.map {|c| c << " LIKE :search" }.join(" OR ")
                @collection = @collection.where(clauses, {:search => "%#{param(:q)}%"})
              rescue
                Rails.logger.debug "Given collection doesn't respond to :where well"
                @collection = orig_collection
              end
            end
          end
        end
      else
        if @options[:searchable] or param(:q)
          Rails.logger.warn "#{self.class.name}: Ignoring searchable fields on non-AR collection"
        end
        @options[:searchable] = false
      end
      if not @options[:searcher] and @options[:searchable]
        @options[:needs_searcher] = true
        @options[:searcher] = param_key(:searcher)
      end
      # Do collection filter first, may convert from AR to Array
      if @options[:collection_post_filter?] and @collection.respond_to?(:post_filter)
        @collection = @collection.post_filter(controller)
      end
      if @options[:post_filter] and @options[:post_filter].respond_to?(:call)
        @collection = @options[:post_filter].call(@collection)
      end
      # Paginate at the very end, after all sorting, filtering, etc..
      if @options[:per_page]
        if @collection.respond_to? :paginate
          @collection = @collection.paginate(:page => param(:page, 1),
                                             :per_page => @options[:per_page])
        elsif @collection.respond_to? :page
          @collection = @collection.page(param(:page, 1)).per(@options[:per_page])
        elsif Module.const_defined? :Kaminari
          @collection = Kaminari.paginate_array(@collection).page(param(:page, 1)).per(@options[:per_page])
        else
          @collection = @collection.each_slice(@options[:per_page]).drop([param(:page, 1) - 1, 0].max)
        end
      end
    end

    def param_key(key)
      "#{@magic_id}_#{key}".to_sym
    end

    def param(key, default=nil)
      @params.fetch(param_key(key), default)
    end

    def base_params
      @params.merge :magic_grid_id => @magic_id
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
