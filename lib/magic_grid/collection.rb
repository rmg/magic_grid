require 'active_support'

module MagicGrid
  class Collection

    def initialize(collection, grid)
      @collection = collection
      @grid = grid
      @current_page = 1
    end

    delegate :map, :count, :to => :collection

    attr_writer :logger, :grid
    attr_reader :collection, :grid
    attr_reader :current_page, :original_count, :total_pages, :paginated

    def logger
      @logger || (@grid && @grid.logger) || Rails.logger
    end

    def self.[](collection, grid)
      if collection.is_a?(self)
        collection.grid = grid
        collection
      else
        Collection.new(collection, grid)
      end
    end

    def search_using_builtin(q)
      @collection.__send__(@grid.options[:search_method], q)
    end

    def quote_column_name(col)
      @collection.connection.quote_column_name(col.to_s)
    end

    def search_using_where(q)
      result = @collection
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
          result = @collection.where(clauses, {:search => "%#{q}%"})
        rescue
          self.logger.debug "Given collection doesn't respond to :where well"
        end
      end
      result
    end

    def sortable?
      @collection.respond_to?(:order)
    end

    def apply_sort(col, dir)
      @collection = @collection.order("#{col} #{dir}")
      self
    end

    def searchable?
      search_method = @grid.options[:search_method]
      (@collection.respond_to?(:where) or (search_method and @collection.respond_to?(search_method)))
    end

    def apply_search(q)
      @collection = search_using_builtin(q)
    rescue
      self.logger.debug "Given collection doesn't respond to #{@grid.options[:search_method]} well"
      @collection = search_using_where(q)
    ensure
      self
    end

    def apply_pagination(current_page, per_page)
      if per_page
        @original_count = @collection.count
        @total_pages = @original_count / per_page
        @current_page = current_page
        if @collection.respond_to? :paginate
          @collection = @collection.paginate(:page => current_page,
                                             :per_page => per_page)
        elsif @collection.respond_to? :page
          @collection = @collection.page(current_page).per(per_page)
        elsif @collection.is_a?(Array) and Module.const_defined?(:Kaminari)
          @collection = Kaminari.paginate_array(@collection).page(current_page).per(per_page)
        else
          @collection = @collection.to_enum
          @collection = @collection.each_slice(per_page)
          @collection = @collection.drop(current_page - 1)
          @collection = @collection.first.to_a
          class << @collection
            attr_accessor :current_page, :total_pages, :original_count
          end
        end
        @paginated = @collection
      end
      self
    end

  end
end