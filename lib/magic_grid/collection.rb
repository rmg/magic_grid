require 'active_support/core_ext'
require 'magic_grid/logger'

module MagicGrid
  class Collection

    DEFAULTS = {
      :per_page => 30,
      :searchable => [],
      :search_method => :search,
      :listener_handler => nil,
      :default_col => 0,
      :default_order => :asc,
      :post_filter => false,
      :collection_post_filter => true,
      :count => nil,
    }

    def initialize(collection, opts = {})
      @collection = collection || []
      self.options = opts
      @current_page = 1
      @sorts = []
      @filter_callbacks = []
      @filters = []
      @searches = []
      @post_filters = []
      @post_filter_callbacks = []
      @paginations = []
      @searchable_columns = []
    end

    delegate :quoted_table_name, :map, :count, :to => :collection

    attr_accessor :searchable_columns
    attr_reader :current_page, :original_count, :total_pages, :per_page, :searches

    def options=(opts)
      @options = DEFAULTS.merge(opts || {})
    end

    def count_options
      @options[:count]
    end

    def self.create_or_reuse(collection, opts = {})
      if collection.is_a?(self)
        collection.options = opts
        collection
      else
        Collection.new(collection, opts)
      end
    end

    def column_names
      @collection.table.columns.map{|c| c[:name]}
    rescue
      MagicGrid.logger.debug("Given collection doesn't respond to #table well: #{$!}")
      []
    end

    def quote_column_name(col)
      if col.is_a? Symbol and @collection.respond_to? :quoted_table_name
        "#{quoted_table_name}.#{@collection.connection.quote_column_name(col.to_s)}"
      else
        col.to_s
      end
    end

    def hash_string
      if @collection.respond_to? :to_sql
        @collection.to_sql.hash.abs.to_s(36)
      else
        @options.hash.abs.to_s(36)
      end
    end

    def search_using_builtin(collection, q)
      collection.__send__(@options[:search_method], q)
    end

    def search_using_where(collection, q)
      result = collection
      unless searchable_columns.empty?
        begin
          search_cols = searchable_columns.map {|c| c.custom_sql || c.name }
          clauses = search_cols.map {|c| c << " LIKE :search" }.join(" OR ")
          result = collection.where(clauses, {:search => "%#{q}%"})
        rescue
          MagicGrid.logger.debug "Given collection doesn't respond to :where well"
        end
      end
      result
    end

    def sortable?
      @collection.respond_to?(:order)
    end

    def apply_sort(col, dir)
      if sortable? and col.sortable?
        @reduced_collection = nil
        @sorts << "#{col.custom_sql} #{dir}"
      end
      self
    end

    def searchable?
      (filterable? and not searchable_columns.empty?) or
        (@options[:search_method] and @collection.respond_to? @options[:search_method])
    end

    def apply_search(q)
      if q and not q.empty?
        if searchable?
          @reduced_collection = nil
          @searches << q
        else
          MagicGrid.logger.warn "#{self.class.name}: Ignoring searchable fields on collection"
        end
      end
      self
    end

    def perform_search(collection, q)
      search_using_builtin(collection, q)
    rescue
      MagicGrid.logger.debug "Given collection doesn't respond to #{@options[:search_method]} well"
      search_using_where(collection, q)
    end

    def filterable?
      @collection.respond_to? :where
    end

    def apply_filter(filters = {})
      if filterable? and not filters.empty?
        @reduced_collection = nil
        @filters << filters
      end
      self
    end

    def apply_filter_callback(callback)
      if callback.respond_to? :call
        @reduced_collection = nil
        @filter_callbacks << callback
      end
      self
    end

    def add_post_filter_callback(callback)
      if callback.respond_to? :call
        @reduced_collection = nil
        @post_filter_callbacks << callback
      end
      self
    end

    def has_post_filter?
      @collection.respond_to? :post_filter
    end

    def enable_post_filter(yes = true)
      @reduced_collection = nil
      if yes and has_post_filter?
        @post_filters << :post_filter
      end
      self
    end

    def count(collection = nil)
      count_or_hash = collection || @collection
      while count_or_hash.respond_to? :count
        count_or_hash = count_or_hash.send :count, *(Array([count_options]).compact)
      end
      count_or_hash
    end

    def per_page=(n)
      @original_count = self.count @collection
      @per_page = n
      if @per_page
        @total_pages = @original_count / @per_page
      else
        @total_pages = 1
      end
    end

    def apply_pagination(current_page)
      @current_page = current_page
      @reduced_collection = nil
      self
    end

    def default_paginate(collection, page, per_page)
      collection = collection.to_enum
      collection = collection.each_slice(@per_page)
      collection = collection.drop(@current_page - 1)
      collection = collection.first.to_a
      class << collection
        attr_accessor :current_page, :total_pages, :original_count
      end
      collection
    end

    def perform_pagination(collection)
      return collection unless @per_page

      total_entries = count(collection)
      @current_page = bound_current_page(@current_page,
                                         @per_page,
                                         total_entries)

      if collection.respond_to? :paginate
        collection.paginate(:page => @current_page,
                            :per_page => @per_page,
                            :total_entries => total_entries)
      elsif collection.respond_to? :page
        collection.page(@current_page).per(@per_page)
      elsif collection.is_a?(Array) and Module.const_defined?(:Kaminari)
         Kaminari.paginate_array(collection).page(@current_page).per(@per_page)
      else
         default_paginate(collection, @current_page, @per_page)
      end
    end

    def apply_all_operations(collection)
      @sorts.each do |ordering|
        collection = collection.order(ordering)
      end
      if @filter_callbacks.empty?
        @filters.each do |hsh|
          collection = collection.where(hsh)
        end
      else
        @filter_callbacks.each do |callback|
          collection = callback.call(collection)
        end
      end
      @searches.each do |query|
        collection = perform_search(collection, query)
      end
      # Do collection filter first, may convert from AR to Array
      @post_filters.each do |filter|
        collection = collection.__send__(filter)
      end
      @post_filter_callbacks.each do |callback|
        collection = callback.call(collection)
      end
      # Paginate at the very end, after all sorting, filtering, etc..
      perform_pagination(collection)
    end

    def collection
      @reduced_collection ||= apply_all_operations(@collection)
    end

    private

    def bound_current_page(page, per_page, total_entries)
      pages = total_entries / per_page
      pages = 1 if pages == 0
      if page > pages
        pages
      else
        page
      end
    end
  end
end
