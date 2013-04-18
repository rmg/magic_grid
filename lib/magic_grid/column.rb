require 'magic_grid/order'

module MagicGrid
  class Column
    attr_accessor :order

    def self.columns_for_collection(collection, columns, searchables)
      columns.each_with_index.map { |c, i|
        MagicGrid::Column.new(collection, c, i)
      }.tap do |cols|
        if searchables == false
          searchables = []
        else
          searchables = Array(searchables).map { |s|
            searchable_column(s, cols, collection)
          }
        end
        collection.searchable_columns = searchables.compact
      end
    end

    def self.searchable_column(searchable, columns, collection)
      case searchable
      when Symbol
        columns.find {|col| col.name == searchable} || FilterOnlyColumn.new(searchable, collection)
      when Integer
        columns[searchable]
      when String
        FilterOnlyColumn.new(searchable)
      when true
        nil
      else
        raise "Searchable must be identifiable: #{searchable}"
      end
    end

    def self.hash_string(column_or_columns)
      Array(column_or_columns).map(&:label).join.hash.abs.to_s(36)
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
      @html_classes ||= (Array(@col[:class]) << order.css_class)
      @html_classes.join(' ')
    end

    def reader
      @col[:to_s] || @col[:col]
    end

    private
    def initialize(collection, c, i)
      @collection = collection
      @col =  case c
              when Symbol
                {:col => c}
              when String
                {:label => c}
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
      @order = Order::Unordered
      @name = name
      if collection
        @custom_sql = collection.quote_column_name(name)
      else
        @custom_sql = name
      end
    end
  end
end