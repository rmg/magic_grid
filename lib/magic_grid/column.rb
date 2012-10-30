module MagicGrid
  class Column

    def self.columns_for_collection(collection, columns, searchables)
      columns.map.each_with_index { |c, i|
        MagicGrid::Column.new(collection, c, i)
      }.tap do |cols|
        collection.searchable_columns = Array(searchables).map { |searchable|
          case searchable
          when Symbol
            cols.find {|col| col.name == searchable} || FilterOnlyColumn.new(searchable, collection)
          when Integer
            cols[searchable]
          when String
            FilterOnlyColumn.new(searchable)
          else
            raise "Searchable must be identifiable"
          end
        }.compact
      end
    end

    def label
      @col[:label]
    end

    def sortable?
      not custom_sql.blank?
    end

    def custom_sql
      @col[:sql]
    end

    def id
      @col[:id]
    end

    def name
      @col[:col]
    end

    def html_classes
      Array(@col[:class]).join ' '
    end

    def reader
      @col[:to_s] || @col[:col]
    end

    private
    def initialize(collection, c, i)
      @collection = collection
      @col = case c
              when Symbol
                {col: c}
              when String
                {label: c}
              else
                c
              end
      @col[:id] = i
      if @collection.column_names.include?(@col[:col])
        @col[:sql] ||= @collection.quote_column_name(name)
      end
      @col[:label] ||= @col[:col].to_s.titleize
    end

  end

  class FilterOnlyColumn < Column
    attr_reader :name, :custom_sql
    def initialize(name, collection = nil)
      @name = name
      if collection
        @custom_sql = collection.quote_column_name(name)
      else
        @custom_sql = name
      end
    end
  end
end