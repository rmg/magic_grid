require 'magic_grid/logger'
require 'magic_grid/collection'
require 'magic_grid/column'

module MagicGrid
  class Definition
    attr_reader :columns, :options, :params,
      :current_sort_col, :current_order, :default_order, :per_page

    def magic_collection
      @collection
    end

    def collection
      @collection.collection
    end

    COLLECTION_DEFAULTS = {
      per_page: 30,
      searchable: [],
      search_method: :search,
      listener_handler: nil,
      default_col: 0,
      default_order: :asc,
      post_filter: false,
      collection_post_filter: true,
    }

    GRID_DEFAULTS = {
      class: [],
      top_pager: false,
      bottom_pager: true,
      remote: false,
      min_search_length: 3,
      id: false,
      searcher: false,
      needs_searcher: false,
      live_search: false,
      current_search: nil,
      listeners: {},
      empty_header: false,
      empty_footer: false,
      default_ajax_handler: true,
      search_button: false,
      searcher_size: nil,
    }

    DEFAULTS = GRID_DEFAULTS.merge COLLECTION_DEFAULTS

    def self.runtime_defaults
      # run these lazily to catch any late I18n path changes
      DEFAULTS.merge(
        if_empty:         I18n.t("magic_grid.no_results").capitalize, # "No results found."
        searcher_label:   I18n.t("magic_grid.search.label").capitalize + ': ', # "Search: "
        searcher_tooltip: I18n.t("magic_grid.search.tooltip"), # "type.. + <return>"
        searcher_button:  I18n.t("magic_grid.search.button").capitalize, # "Search"
      )
    end

    def initialize(cols_or_opts, collection = nil, controller = nil, opts = {})
      if cols_or_opts.is_a? Hash
        @options = self.class.runtime_defaults.merge(cols_or_opts.reject {|k| k == :cols})
        @columns = cols_or_opts.fetch(:cols, [])
      elsif cols_or_opts.is_a? Array
        @options = self.class.runtime_defaults.merge opts
        @columns = cols_or_opts
      else
        raise "I have no idea what that is, but it's not a columns list or options hash"
      end
      @default_order = @options[:default_order]
      @params = controller && controller.params || {}
      @per_page = @options[:per_page]
      @collection = Collection[collection, self]
      @columns = MagicGrid::Column.columns_for_collection(@collection, @columns)
      @current_sort_col = param(:col, @options[:default_col]).to_i
      unless (0...@columns.count).cover? @current_sort_col
        @current_sort_col = @options[:default_col]
      end
      if @collection.sortable? and @columns[@current_sort_col].sortable?
        sort_col = @columns[@current_sort_col].custom_sql
        @current_order = order(param(:order, @default_order))
        sort_dir = order_sql(@current_order)
        @collection.apply_sort(sort_col, sort_dir)
      else
        MagicGrid.logger.debug "#{self.class.name}: Ignoring sorting on collection"
      end

      @collection.apply_filter_callback @options[:listener_handler]
      @options[:listeners].each_pair do |key, value|
        if @params[value] and not @params[value].to_s.empty?
          @collection.apply_filter(value => @params[value])
        end
      end
      @options[:current_search] ||= param(:q)
      @collection.searchable_columns = Array(@options[:searchable])
      @collection.apply_search @options[:current_search]
      @collection.enable_post_filter @options[:collection_post_filter?]
      @collection.add_post_filter_callback @options[:post_filter]
      @collection.apply_pagination(current_page, @per_page)
    end

    def magic_id
      if @options[:id]
        @magic_id = @options[:id]
      else
        @magic_id = @columns.map(&:label).join.hash.abs.to_s(36)
        @magic_id << @collection.to_sql.hash.abs.to_s(36) if @collection.respond_to? :to_sql
      end
      @magic_id
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
      @params.merge magic_grid_id: magic_id
    end

    def current_page
      [param(:page, 1).to_i, 1].max
    end

    def order(something)
      case something
      when 1, "1", :desc, :DESC, "desc", "DESC"
        1
      #when 0, "0", :asc, :ASC, "asc", "ASC"
      #  0
      else
        0
      end
    end

    def order_sql(something)
      ["ASC", "DESC"][order(something)]
    end
  end
end
