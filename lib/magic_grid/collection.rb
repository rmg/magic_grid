require 'delegate'

module MagicGrid
  class Collection < Delegator
    def self.[](collection, grid)
      if collection.is_a?(Collection)
        collection.grid = grid
      else
        collection = Collection.new(collection, grid)
      end
      collection
    end

    attr_writer :grid

    def initialize(collection, grid)
      super(collection)
      @collection = collection
      @grid = grid
    end

    def __getobj__
      @collection
    end

    def __setobj__(obj)
      @collection = obj
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
          Rails.logger.debug "Given collection doesn't respond to :where well"
        end
      end
      result
    end

    def searchable?
      search_method = @grid.options[:search_method]
      (@collection.respond_to?(:where) or (search_method and @collection.respond_to?(search_method)))
    end

    def apply_search(q)
      @collection = search_using_builtin(q)
    rescue
      Rails.logger.debug "Given collection doesn't respond to #{@grid.options[:search_method]} well"
      @collection = search_using_where(q)
    ensure
      self
    end
  end
end