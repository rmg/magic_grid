require 'active_support/core_ext'
require 'magic_grid/logger'

module MagicGrid
  class Collection

    def initialize(collection, grid)
      @collection = collection || []
      @grid = grid
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

    delegate :quoted_table_name, :map, :count, to: :collection

    attr_accessor :grid, :searchable_columns
    attr_reader :current_page, :original_count, :total_pages

    def self.[](collection, grid)
      if collection.is_a?(self)
        collection.grid = grid
        collection
      else
        Collection.new(collection, grid)
      end
    end

    def column_names
      @collection.table.column_names
    rescue
      MagicGrid.logger.debug("Given collection doesn't respond to #table well: #{$!}")
      []
    end

    def quote_column_name(col)
      @collection.connection.quote_column_name(col.to_s)
    end

    def search_using_builtin(collection, q)
      collection.__send__(@grid.options[:search_method], q)
    end

    def search_using_where(collection, q)
      result = collection
      search_cols = @grid.options[:searchable].map do |searchable|
        case searchable
        when Symbol
          known = @grid.columns.find {|col| col.name == searchable}
          known && known.custom_sql || "#{@collection.table_name}.#{quote_column_name(searchable)}"
        when Integer
          @grid.columns[searchable].custom_sql
        when String
          searchable
        else
          raise "Searchable must be identifiable"
        end
      end

      unless search_cols.empty?
        begin
          clauses = search_cols.map {|c| c << " LIKE :search" }.join(" OR ")
          result = collection.where(clauses, {search: "%#{q}%"})
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
      @reduced_collection = nil
      @sorts << "#{col} #{dir}"
      self
    end

    def searchable?
      filterable? and not searchable_columns.empty? or
        @collection.respond_to? @grid.options[:search_method]
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
      MagicGrid.logger.debug "Given collection doesn't respond to #{@grid.options[:search_method]} well"
      search_using_where(collection, q)
    end

    def filterable?
      @collection.respond_to? :where
    end

    def apply_filter(filters = {})
      if filterable?
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
        count_or_hash = count_or_hash.count
      end
      count_or_hash
    end

    def apply_pagination(current_page, per_page)
      @original_count = self.count @collection
      @per_page = per_page ? per_page : @original_count
      if @per_page == 0 and @original_count == 0
        @total_pages = @per_page = 1
      else
        @total_pages = @original_count / @per_page
      end
      @current_page = current_page
      @reduced_collection = nil
      self
    end

    def perform_pagination(collection)
      return collection unless @per_page

      if collection.respond_to? :paginate
        collection = collection.paginate(page: @current_page,
                                         per_page: @per_page)
      elsif collection.respond_to? :page
        collection = collection.page(@current_page).per(@per_page)
      elsif collection.is_a?(Array) and Module.const_defined?(:Kaminari)
        collection = Kaminari.paginate_array(collection).page(@current_page).per(@per_page)
      else
        collection = collection.to_enum
        collection = collection.each_slice(@per_page)
        collection = collection.drop(@current_page - 1)
        collection = collection.first.to_a
        class << collection
          attr_accessor :current_page, :total_pages, :original_count
        end
      end

      collection
    end

    def apply_all_operations(collection)
      @sorts.each do |ordering|
        collection = collection.order(ordering)
      end
      @filter_callbacks.each do |callback|
        collection = callback.call(collection)
      end
      @filters.each do |hsh|
        collection = collection.where(hsh)
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

  end
end
