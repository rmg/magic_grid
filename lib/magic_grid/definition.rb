require 'will_paginate/view_helpers/action_view'

module MagicGrid
  class Definition
    include WillPaginate::ActionView
    attr_accessor :columns, :collection, :magic_id, :options

    DEFAULTS = {
      :wide => false,
      :prefix => '',
      :top_pager => true,
      :bottom_pager => false,
      :ajax => false,
    }

    def initialize(cols_or_opts, collection = nil, params = {}, opts = {})
      Rails.logger.debug "#{self.class}( #{collection.class} )"
      if cols_or_opts.is_a? Hash
        @options = DEFAULTS.merge(cols_or_opts.reject {|k| k == :cols})
        @columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        @options = DEFAULTS.merge opts
        @columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a Hash or an Array"
      end
      @collection = collection
      if @collection.respond_to? :table
        table_name = @collection.quoted_table_name
        table_columns = @collection.table.columns.map {|c| c.name}
      else
        table_name = nil
        table_columns = @columns.each_index.to_a
      end
      i = 0
      hash = []
      @columns.map! do |c|
        c = {:col => c} if c.is_a? String or c.is_a? Symbol
        c[:id] = i
        i += 1
        if c[:col].is_a? Symbol and table_columns.include? c[:col]
          c[:sql] = "#{table_name}.#{c[:col].to_s}"
        end
        c[:label] = c[:col].to_s.titleize if not c.key? :label
        hash << c[:label]
        c
      end
      @magic_id = hash.join.hash.abs.to_s(36)
      @magic_id += @collection.to_sql.hash.abs.to_s(36) if @collection.respond_to? :to_sql
      sort_col_i = params.fetch(:col, opts.fetch(:default_col, 0)).to_i
      if @collection.respond_to? :order and @columns.count > sort_col_i and @columns[sort_col_i].has_key? :sql
        sort_col = @columns[sort_col_i][:sql]
        sort_dir_i = params.fetch(:order, opts.fetch(:default_order, 0)).to_i
        sort_dir = ['ASC', 'DESC'][sort_dir_i == 0 ? 0 : 1]
        @collection = @collection.order("#{sort_col} #{sort_dir}")
      end
      @collection = @collection.paginate(:page => params.fetch(:page, 1))
    end
  end
end
