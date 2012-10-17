require 'active_support/core_ext'
require 'magic_grid/logger'

module MagicGrid
  class Collection

    def initialize(collection, grid)
      @collection = collection
      @grid = grid
      @current_page = 1
      @sorts = []
      @filter_callbacks = []
      @filters = []
      @searches = []
      @post_filters = []
      @post_filter_callbacks = []
      @paginations = []
    end

    delegate :quoted_table_name, :map, :count, :to => :collection

    attr_accessor :grid
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
      @collection.table.columns.map {|c| c.name}
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
          known = @grid.columns.find {|col| col[:col] == searchable}
          if known and known.key?(:sql)
            known[:sql]
          else
            "#{@collection.table_name}.#{quote_column_name(searchable)}"
          end
        when Integer
          @grid.columns[searchable][:sql]
        when String
          searchable
        else
          raise "Searchable must be identifiable"
        end
      end

      unless search_cols.empty?
        begin
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
      @sorts << "#{col} #{dir}"
      self
    end

    def searchable?
      filterable? or @collection.respond_to? @grid.options[:search_method]
    end

    def apply_search(q)
      @searches << q
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
      if @collection.respond_to? :where
        @filters << filters
      end
      self
    end

    def apply_filter_callback(callback)
      if callback.respond_to? :call
        @filter_callbacks << callback
      end
      self
    end

    def has_post_filter?
      @collection.respond_to? :post_filter
    end

    def apply_post_filter
      @post_filters << :post_filter
      self
    end

    def apply_pagination(current_page, per_page)
      if per_page
        @paginations << {:current_page => current_page, :per_page => per_page}
      end
      self
    end

    def perform_pagination(collection, current_page, per_page)
      @original_count = @collection.count
      @total_pages = @original_count / per_page
      @current_page = current_page
      if collection.respond_to? :paginate
        collection = collection.paginate(:page => current_page,
                                           :per_page => per_page)
      elsif collection.respond_to? :page
        collection = collection.page(current_page).per(per_page)
      elsif collection.is_a?(Array) and Module.const_defined?(:Kaminari)
        collection = Kaminari.paginate_array(collection).page(current_page).per(per_page)
      else
        collection = collection.to_enum
        collection = collection.each_slice(per_page)
        collection = collection.drop(current_page - 1)
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
      @post_filters.each do |filter|
        collection = collection.__send__(filter)
      end
      @post_filter_callbacks.each do |callback|
        collection = callback.call(collection)
      end
      @paginations.each do |params|
        collection = perform_pagination(collection, params[:current_page], params[:per_page])
      end
      collection
    end

    def collection
      @reduced_collection ||= apply_all_operations(@collection)
    end



  end
end
