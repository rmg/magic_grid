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

    def perform_search(q)
      orig_collection = self
      begin
        @collection = @collection.__send__(@grid.options[:search_method], q)
      rescue
        Rails.logger.debug "Given collection doesn't respond to #{@grid.options[:search_method]} well"
        @collection = orig_collection
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
            @collection = @collection.where(clauses, {:search => "%#{param(:q)}%"})
          rescue
            Rails.logger.debug "Given collection doesn't respond to :where well"
            @collection = orig_collection
          end
        end
      end
      self
    end
  end
end