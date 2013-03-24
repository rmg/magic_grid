require 'magic_grid/logger'
require 'magic_grid/collection'
require 'magic_grid/column'
require 'magic_grid/order'
require 'active_support/core_ext'

module MagicGrid
  class Definition
    attr_reader :columns, :options, :params

    def magic_collection
      @collection
    end

    def collection
      @collection.collection
    end

    DEFAULTS = {
      :class                 => [],
      :top_pager             => false,
      :bottom_pager          => true,
      :remote                => false,
      :min_search_length     => 3,
      :id                    => false,
      :searcher              => false,
      :needs_searcher        => false,
      :live_search           => false,
      :listeners             => {},
      :collapse_empty_header => false,
      :collapse_empty_footer => false,
      :default_ajax_handler  => true,
      :default_order         => :asc,
      :search_button         => false,
      :searcher_size         => nil,
    }

    def self.runtime_defaults
      # run these lazily to catch any late I18n path changes
      DEFAULTS.merge(Collection::DEFAULTS).merge(
        :if_empty         => I18n.t("magic_grid.no_results").capitalize, # "No results found."
        :searcher_label   => I18n.t("magic_grid.search.label").capitalize + ': ', # "Search: "
        :searcher_tooltip => I18n.t("magic_grid.search.tooltip"), # "type.. + <return>"
        :searcher_button  => I18n.t("magic_grid.search.button").capitalize # "Search"
      )
    end

    def self.normalize_columns_options(cols_or_opts, opts)
      case cols_or_opts
      when Hash
        options = runtime_defaults.merge(cols_or_opts.reject {|k| k == :cols})
        columns = cols_or_opts.fetch(:cols, [])
      when Array
        options = runtime_defaults.merge opts
        columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a columns list or options hash"
      end
      [options, columns]
    end

    def initialize(cols_or_opts, collection = nil, controller = nil, opts = {})
      @options, @columns = *self.class.normalize_columns_options(cols_or_opts, opts)
      @params = controller && controller.params || {}

      @collection = Collection.create_or_reuse collection, options

      @columns = Column.columns_for_collection(magic_collection,
                                               columns,
                                               options[:searchable])

      magic_collection.apply_sort(columns[current_sort_col], current_order.to_sql)

      magic_collection.apply_filter filters
      magic_collection.apply_pagination(current_page)
      magic_collection.apply_search current_search

      magic_collection.per_page = options[:per_page]
      magic_collection.apply_filter_callback options[:listener_handler]
      magic_collection.enable_post_filter options[:collection_post_filter]
      magic_collection.add_post_filter_callback options[:post_filter]
    end

    def filters
      @filters ||= begin
        filter_keys = options[:listeners].values
        params.slice(*filter_keys).reject {|k,v| v.to_s.empty? }
      end
    end

    def current_sort_col
      @current_sort_col ||= begin
        given = param(:col)
        if (0...columns.count).cover? given
          given
        else
          options[:default_col].to_i
        end
      end
    end

    def default_order
      @default_order ||= Order.from_param(options[:default_order])
    end

    def current_order
      @current_order ||= Order.from_param(param(:order, default_order.to_param))
    end

    def current_search
      param(:q)
    end

    def magic_id
      options[:id] || (Column.hash_string(columns) + magic_collection.hash_string)
    end

    def searchable?
      magic_collection.searchable?
    end

    def needs_searcher?
      options[:needs_searcher] or (searchable? and not options[:searcher])
    end

    def searcher
      if needs_searcher?
        param_key(:searcher)
      else
        options[:searcher]
      end
    end

    def param_key(key)
      "#{magic_id}_#{key}".to_sym
    end

    def param(key, default=nil)
      params.fetch(param_key(key), default)
    end

    def base_params
      params.merge :magic_grid_id => magic_id
    end

    def current_page
      [param(:page, 1).to_i, 1].max
    end
  end
end
