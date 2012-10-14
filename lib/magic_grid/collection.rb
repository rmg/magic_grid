require 'delegate'

module MagicGrid
  class Collection < Delegator
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

    def search_using_where(q)
      result = @collection
      search_cols = @grid.options[:searchable].map do |searchable|
        case searchable
        when Symbol
          known = @grid.columns.find {|col| col[:col] == searchable}
          if known and known.key?(:sql)
            known[:sql]
          else
            "#{table_name}.#{@collection.connection.quote_column_name(searchable.to_s)}"
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
          result = @collection.where(clauses, {:search => "%#{param(:q)}%"})
        rescue
          Rails.logger.debug "Given collection doesn't respond to :where well"
        end
      end
      result
    end

    def apply_search(q)
      begin
        @collection = search_using_builtin(q)
      rescue
        Rails.logger.debug "Given collection doesn't respond to #{@grid.options[:search_method]} well"
        @collection = search_using_where(q)
      end
      self
    end
  end
end