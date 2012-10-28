module MagicGrid
  class Column

    def self.columns_for_collection(collection, columns)
      columns.map.each_with_index do |c, i|
        MagicGrid::Column.new(collection, c, i)
      end
    end

    def label
      @col[:label]
    end

    def sortable?
      @col.has_key?(:sql)
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
        @col[:sql] = "#{@collection.quoted_table_name}.#{@collection.quote_column_name(@col[:col].to_s)}" unless @col.key?(:sql)
      end
      @col[:label] ||= @col[:col].to_s.titleize
    end

  end
end