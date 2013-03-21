require 'magic_grid/logger'
require 'magic_grid/collection'
require 'magic_grid/column'
require 'magic_grid/order'
require 'active_support/core_ext'

module MagicGrid
  class Definition
    attr_reader :columns, :options, :params,
      :current_sort_col, :current_order, :default_order

    def magic_collection
      @collection
    end

    def collection
      @collection.collection
    end

    DEFAULTS = {
      :class => [],
      :top_pager => false,
      :bottom_pager => true,
      :remote => false,
      :min_search_length => 3,
      :id => false,
      :searcher => false,
      :needs_searcher => false,
      :live_search => false,
      :listeners => {},
      :collapse_empty_header => false,
      :collapse_empty_footer => false,
      :default_ajax_handler => true,
      :default_order => :asc,
      :search_button => false,
      :searcher_size => nil,
    }

    def self.runtime_defaults
      # run these lazily to catch any late I18n path changes
      DEFAULTS.merge(Collection::DEFAULTS).merge(
        :if_empty =>         I18n.t("magic_grid.no_results").capitalize, # "No results found."
        :searcher_label =>   I18n.t("magic_grid.search.label").capitalize + ': ', # "Search: "
        :searcher_tooltip => I18n.t("magic_grid.search.tooltip"), # "type.. + <return>"
        :searcher_button =>  I18n.t("magic_grid.search.button").capitalize # "Search"
      )
    end

    def self.normalize_columns_options(cols_or_opts, opts)
      if cols_or_opts.is_a? Hash
        options = runtime_defaults.merge(cols_or_opts.reject {|k| k == :cols})
        columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        options = runtime_defaults.merge opts
        columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a columns list or options hash"
      end
      [options, columns]
    end

    def initialize(cols_or_opts, collection = nil, controller = nil, opts = {})
      @options, @columns = *self.class.normalize_columns_options(cols_or_opts, opts)
      @default_order = Order.from_param(@options[:default_order])
      @params = controller && controller.params || {}

      @collection = Collection.create_or_reuse collection, @options

      @columns = Column.columns_for_collection(@collection,
                                               @columns,
                                               @options[:searchable])

      @current_sort_col = param(:col, @options[:default_col]).to_i
      unless (0...@columns.count).cover? @current_sort_col
        @current_sort_col = @options[:default_col]
      end
      @current_order = Order.from_param(param(:order, @default_order))
      @collection.apply_sort(@columns[@current_sort_col], order_sql(@current_order))

      filter_keys = @options[:listeners].values
      filters = @params.slice(*filter_keys).reject {|k,v| v.to_s.empty? }
      @collection.apply_filter filters
      @collection.apply_pagination(current_page)
      @collection.apply_search current_search

      @collection.per_page = @options[:per_page]
      @collection.apply_filter_callback @options[:listener_handler]
      @collection.enable_post_filter @options[:collection_post_filter]
      @collection.add_post_filter_callback @options[:post_filter]
    end

    def current_search
      param(:q)
    end

    def magic_id
      @options[:id] || (Column.hash_string(@columns) + @collection.hash_string)
    end

    def searchable?
      @collection.searchable?
    end

    def needs_searcher?
      @options[:needs_searcher] or (searchable? and not @options[:searcher])
    end

    def searcher
      if needs_searcher?
        param_key(:searcher)
      else
        @options[:searcher]
      end
    end

    def param_key(key)
      "#{magic_id}_#{key}".to_sym
    end

    def param(key, default=nil)
      @params.fetch(param_key(key), default)
    end

    def base_params
      @params.merge :magic_grid_id => magic_id
    end

    def current_page
      [param(:page, 1).to_i, 1].max
    end

    def order_sql(something)
      Order.from_param(something).reverse.to_sql
    end
  end
end
