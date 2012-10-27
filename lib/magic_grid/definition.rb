require 'magic_grid/logger'
require 'magic_grid/collection'

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

    DEFAULTS = {
      :class => [],
      :top_pager => false,
      :bottom_pager => true,
      :remote => false,
      :per_page => 30,
      :searchable => [],
      :search_method => :search,
      :min_search_length => 3,
      :id => false,
      :searcher => false,
      :needs_searcher => false,
      :live_search => false,
      :current_search => nil,
      :listeners => {},
      :listener_handler => nil,
      :default_col => 0,
      :default_order => :asc,
      :empty_header => false,
      :empty_footer => false,
      :post_filter => false,
      :collection_post_filter? => true,
      :default_ajax_handler => true,
      :search_button => false,
      :searcher_size => nil,
    }

    def self.runtime_defaults
      # run these lazily to catch any late I18n path changes
      DEFAULTS.merge(
        :if_empty => I18n.t("magic_grid.no_results").capitalize, # "No results found."
        :searcher_label => I18n.t("magic_grid.search.label").capitalize + ': ', # "Search: "
        :searcher_tooltip =>I18n.t("magic_grid.search.tooltip"), # "type.. + <return>"
        :searcher_button =>I18n.t("magic_grid.search.button").capitalize, # "Search"
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
        raise "I have no idea what that is, but it's not a Hash or an Array"
      end
      @default_order = @options[:default_order]
      @params = controller && controller.params || {}
      @per_page = @options[:per_page]
      @collection = Collection[collection, self]
      @columns.map!.each_with_index do |c, i|
        create_column(c, i)
      end
      @current_sort_col = sort_col_i = param(:col, @options[:default_col]).to_i
      if @collection.sortable? and @columns.count > sort_col_i and @columns[sort_col_i].has_key?(:sql)
        sort_col = @columns[sort_col_i][:sql]
        @current_order = order(param(:order, @default_order))
        sort_dir = order_sql(@current_order)
        @collection.apply_sort(sort_col, sort_dir)
      else
        MagicGrid.logger.debug "#{self.class.name}: Ignoring sorting on non-AR collection"
      end

      if @collection.filterable? or @options[:listener_handler].respond_to?(:call)
        if @options[:listener_handler].respond_to? :call
          @collection.apply_filter_callback @options[:listener_handler]
        else
          @options[:listeners].each_pair do |key, value|
            if @params[value] and not @params[value].to_s.empty?
              @collection.apply_filter(value => @params[value])
            end
          end
        end
      else
        unless @options[:listeners].empty?
          MagicGrid.logger.warn "#{self.class.name}: Ignoring listener on dumb collection"
          @options[:listeners] = {}
        end
      end

      @options[:searchable] = Array(@options[:searchable])
      @options[:current_search] ||= param(:q)
      if @collection.searchable?
        if param(:q) and not param(:q).empty? and not @options[:searchable].empty?
          @collection.apply_search(param(:q))
        end
      else
        if not @options[:searchable].empty? or param(:q)
          MagicGrid.logger.warn "#{self.class.name}: Ignoring searchable fields on non-AR collection"
        end
        @options[:searchable] = []
      end

      # Do collection filter first, may convert from AR to Array
      if @options[:collection_post_filter?] and @collection.has_post_filter?
        @collection.apply_post_filter
      end
      if @options[:post_filter] and @options[:post_filter].respond_to?(:call)
        @collection.apply_post_filter_callback @options[:post_filter]
      end
      @collection.apply_pagination(current_page, @per_page)
    end

    def magic_id
      if @options[:id]
        @magic_id = @options[:id]
      else
        @magic_id = @columns.map{|c| c[:label]}.join.hash.abs.to_s(36)
        @magic_id << @collection.to_sql.hash.abs.to_s(36) if @collection.respond_to? :to_sql
      end
      @magic_id
    end

    def create_column(c, i)
      if c.is_a? Symbol
        c = {:col => c}
      elsif c.is_a? String
        c = {:label => c}
      end
      c[:id] = i
      if c.key?(:col) and c[:col].is_a?(Symbol) and @collection.column_names(@columns.count).include?(c[:col])
        c[:sql] = "#{@collection.quoted_table_name}.#{@collection.quote_column_name(c[:col].to_s)}" unless c.key?(:sql)
      end
      c[:label] = c[:col].to_s.titleize if not c.key? :label
      c
    end

    def searchable?
      @collection.searchable? and not @options[:searchable].empty?
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
