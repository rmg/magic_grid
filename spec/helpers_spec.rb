require 'spec_helper'
require 'magic_grid/helpers'

def make_controller
  request = double.tap { |r|
    r.stub(:fullpath, "/foo?page=bar")
  }
  double.tap { |v|
    v.stub(:render)
    v.stub(:params) { {} }
    v.stub(:request) { request }
  }
end

def fake_connection
  double(:connection).tap do |c|
    c.stub(:quote_column_name) { |col| col.to_s }
  end
end

def fake_active_record_collection(table_name = 'some_table',
                                  columns = [:name, :description])
  (1..1000).to_a.tap do |c|
    c.stub(connection: fake_connection)
    c.stub(quoted_table_name: table_name)
    c.stub(table_name: table_name)
    c.stub(:where) { c }
    c.stub(:table) {
            double.tap do |t|
              t.stub(:column_names) { columns }
            end
          }
  end
end

describe MagicGrid::Helpers do

  # Let's use the helpers the way they're meant to be used!
  include MagicGrid::Helpers

  let(:empty_collection) { [] }

  let(:column_list) { [:name, :description] }

  let(:controller) { make_controller }

  # Kaminari uses view_renderer instead of controller
  let(:view_renderer) { controller }

  describe "#normalize_magic" do

    it "should turn an array into a MagicGrid::Definition" do
      expect(normalize_magic([])).to be_a(MagicGrid::Definition)
    end

    it "should give back the MagicGrid::Definition given, if given as any argument" do
      definition = normalize_magic([])
      expect(normalize_magic( definition )).to be(definition)
      expect(normalize_magic( nil, definition )).to be(definition)
      expect(normalize_magic( nil, nil, definition )).to be(definition)
    end
  end

  describe "#magic_grid" do
    pending "DOES WAY TOO MUCH!!"

    let(:emtpy_grid) { magic_grid empty_collection, column_list }

    it "should barf without any arguments" do
      expect { magic_grid }.to raise_error
    end

    it "should render a table" do
      expect( emtpy_grid ).not_to be_empty
      expect( emtpy_grid ).to match(/<\/table>/)
    end

    context "when given an empty collection" do
      subject { magic_grid empty_collection, column_list }
      it "should indicate there is no data" do
        subject.should match(/"if-empty"/)
      end
    end

    context "when given an empty collection and an if_empty callback" do
      it "calls the callback" do
        if_emtpy_string = "ZOMG! NO ROWS!"
        callback = double.tap do |cb|
          cb.should_receive(:call).with(instance_of MagicGrid::Definition) {
            if_emtpy_string
          }
        end
        grid = magic_grid empty_collection, column_list, if_empty: callback
        grid.should include(if_emtpy_string)
      end
    end

    context "when given a non-empty collection" do
      subject { magic_grid( [1, 2], [:to_s] ) }
      it "should not indicate there is no data" do
        should_not match(/if-empty/)
      end
      it { should  =~ /<td>1<\/td>/ }
      it { should  =~ /<td>2<\/td>/ }
    end

    context "when given a block" do
      subject {
        magic_grid( [1, 2], [:to_s] ) do |row|
          "HOKY_POKY_ALAMO: #{row}"
        end
      }
      it { should =~ /HOKY_POKY_ALAMO: 1/ }
    end

    context "when given an array of Symbols as column list" do
      subject {
        magic_grid( [1,2], [:col1, :col2]) do |row|
          "draw a row"
        end
      }
      it { should match(/draw a row/) }
      it("capitalizes the column name") { should match(/Col1/) }
      it { should match(/Col2/) }
    end

    context "when given an array of Strings as column list" do
      subject {
        magic_grid( [1,2], ["CamelCase", "lower_case"]) do |row|
          "draw a row"
        end
      }
      it { should match(/draw a row/) }
      it("leaves case alone") { should match(/CamelCase/) }
      it("leaves underscores alone") { should match(/lower_case/) }
    end

    context "renders top and bottom pagers as told" do
      large_collection = (1..1000).to_a

      if Module.const_defined? :Kaminari
        def render(*args)
          "<nav class='pagination'><!-- paginate! --></nav>".html_safe
        end
      end

      it "should render an actual pager" do
        grid = magic_grid(large_collection, [:to_s])
        if Module.const_defined? :WillPaginate
          grid.should match_select("tfoot>tr>td.magic-pager>div.pagination", 1)
        elsif Module.const_defined? :Kaminari
          grid.should match_select("tfoot>tr>td.magic-pager>nav.pagination", 1)
        else
          grid.should match_select("tfoot>tr>td.magic-pager", /INSTALL/)
        end
      end
      it "should render only a bottom pager by default" do
        grid = magic_grid( large_collection, [:to_s] )
        grid.should match_select("thead>tr>td.magic-pager", 0)
        grid.should match_select("tfoot>tr>td.magic-pager", 1)
      end
      it "should render a top and bottom pager when told" do
        grid = magic_grid( large_collection, [:to_s], top_pager: true )
        grid.should match_select("thead>tr>td.magic-pager", 1)
        grid.should match_select("tfoot>tr>td.magic-pager", 1)
      end
      it "should render only a top pager when told" do
        grid = magic_grid( large_collection, [:to_s], top_pager: true, bottom_pager: false )
        grid.should match_select("thead>tr>td.magic-pager", 1)
        grid.should match_select("tfoot>tr>td.magic-pager", 0)
      end
    end

    context "searching" do
      let(:searchabe_collection) {
        collection = [].tap do |c|
          c.stub(:search) { collection }
        end
      }
      it "should render a search bar when asked" do
        grid = magic_grid(searchabe_collection, column_list, searchable: [:some_col])
        grid.should match_select('input[type=search]')
      end

      context "when a search query is given" do
        let(:search_param) { 'foobar' }
        let(:controller) {
          make_controller.tap { |c|
            c.stub(:params) { {grid_id_q: search_param} }
          }
        }
        it "should search a searchable collection when there are search params" do
          collection = (1..1000).to_a
          collection.should_receive(:search).with(search_param) { collection }
          grid = magic_grid(collection, column_list, id: "grid_id", searchable: [:some_col])
          grid.should match_select('input[type=search]')
        end

        context "when the collection responds to #where" do
          it "should call where when there are search params" do
            search_col = :some_col
            table_name = "tbl"
            search_sql = "tbl.some_col"

            collection = fake_active_record_collection(table_name)
            collection.should_receive(:where).
                       with("#{search_sql} LIKE :search", {search: "%#{search_param}%"})

            grid = magic_grid(collection, column_list, id: "grid_id", searchable: [search_col])
          end

          it "should use custom sql from column for call to where when given" do
            search_col = :some_col
            search_sql = "sql that doesn't necessarily match column name"
            table_name = "table name not used in query"

            collection = fake_active_record_collection(table_name)
            collection.should_receive(:where).
                       with("#{search_sql} LIKE :search", {search: "%#{search_param}%"})

            magic_grid(collection,
                       [ :name,
                         :description,
                         {col: search_col, sql: search_sql}
                         ],
                       id: "grid_id", searchable: [search_col])
          end

          it "should use column number to look up search column" do
            search_col = :some_col
            search_sql = "sql that doesn't necessarily match column name"
            table_name = "table name not used in query"

            collection = fake_active_record_collection(table_name)
            collection.should_receive(:where).
                       with("#{search_sql} LIKE :search", {search: "%#{search_param}%"})

            magic_grid(collection,
                       [ :name,
                         :description,
                         {col: search_col, sql: search_sql}
                         ],
                       id: "grid_id", searchable: [2])
          end

          it "should use custom sql for call to where when given" do
            search_col = :some_col
            custom_search_col = "some custom search column"
            search_sql = custom_search_col
            table_name = "table name not used in query"

            collection = fake_active_record_collection(table_name)
            collection.should_receive(:where).
                       with("#{search_sql} LIKE :search", {search: "%#{search_param}%"})

            magic_grid(collection,
                       [ :name,
                         :description,
                         {col: search_col, sql: search_sql}
                         ],
                       id: "grid_id", searchable: [custom_search_col])
          end

          it "should fail when given bad searchable columns" do
            collection = fake_active_record_collection()
            collection.should_not_receive(:where)

            expect {
              magic_grid(collection,
                         [ :name, :description],
                         id: "grid_id", searchable: [nil])
            }.to raise_error
          end

          it "should not fail if #where fails" do
            search_col = :some_col
            table_name = "tbl"
            search_sql = "tbl.some_col"

            collection = fake_active_record_collection(table_name)
            magic_collection = MagicGrid::Collection.new(collection, nil)
            collection.should_receive(:where).and_raise("some failure")
            MagicGrid.logger = double.tap do |l|
              l.should_receive(:debug).at_least(:once)
            end

            expect {
              magic_grid(collection, column_list, id: "grid_id", searchable: [search_col])
            }.to_not raise_error
          end
        end
      end
    end

    context "sorting" do
      let(:sortable_collection) {
        collection = fake_active_record_collection.tap do |c|
          c.stub(:table) {
            double.tap do |t|
              t.stub(:column_names) { column_list }
            end
          }
        end
      }
      it "should render sortable column headers when a collection is sortable" do
        grid = magic_grid(sortable_collection, column_list)
        grid.should match_select("thead>tr>th.sorter>a>span.ui-icon", column_list.count)
      end

      # context "when a sort column is given" do
      #   let(:search_param) { 'foobar' }
      #   let(:controller) {
      #     make_controller.tap { |c|
      #       c.stub(:params) { {grid_id_col: 1} }
      #     }
      #   }
      # end
      # context "when a sort order is given" do
      #   let(:controller) {
      #     make_controller.tap { |c|
      #       c.stub(:params) { {grid_id_order: 1} }
      #     }
      #   }
      # end
      # context "when a sort order and column are given" do
      #   let(:search_param) { 'foobar' }
      #   let(:controller) {
      #     make_controller.tap { |c|
      #       c.stub(:params) { {grid_id_q: 1} }
      #     }
      #   }
      # end
    end

  end

  describe "#magic_row" do
    let(:tracer) { "OMG A MAGIC CELL!" }

    context "with a callable column option" do
      let(:record) { 1 }

      it "should use :to_s as a method if callable" do
        callable = double.tap do |c|
          c.should_receive(:call).with( record ) { tracer }
        end
        cols = [ {col: 'Col', to_s: callable} ]
        collection = MagicGrid::Definition.new(cols)
        magic_row( record , collection ).should include(tracer)
      end

      it "should use :col as a method if callable" do
        callable = double.tap do |c|
          c.should_receive(:call).with( record ) { tracer }
        end
        cols = [ {col: callable, label: "Column"} ]
        collection = MagicGrid::Definition.new(cols)
        magic_row( record , collection ).should include(tracer)
      end
    end

    context "with a symbol that is a method on the record" do
      let(:record) { double(1) }

      it "should use :to_s as a method on record if it responds to it" do
        record.should_receive(:some_inconceivable_method_name) { tracer }
        cols = [ {col: :some_col, to_s: :some_inconceivable_method_name} ]
        collection = MagicGrid::Definition.new(cols)
        magic_row( record , collection ).should include(tracer)
      end

      it "should use :col as a method on record if it responds to it" do
        record.should_receive(:some_inconceivable_method_name) { tracer }
        cols = [ {col: :some_inconceivable_method_name} ]
        collection = MagicGrid::Definition.new(cols)
        magic_row( record , collection ).should include(tracer)
      end
    end
  end

  describe "#magic_headers" do
    it "should allow a string as a column definition" do
      title = "A String"
      cols = [title]
      grid = MagicGrid::Definition.new(cols)
      magic_headers(grid).should include(title)
    end
    it "should use :label if no :sql is given" do
      title = "A String"
      cols = [{label: title}]
      grid = MagicGrid::Definition.new(cols)
      magic_headers(grid).should include(title)
    end
    it "should make a sortable header if :sql is specified" do
      tracer = "A MAGIC BULL??"
      col = {sql: 'some_col'}
      cols = [col]
      grid = MagicGrid::Definition.new(cols)
      # TODO: check parameters to sortable_header
      #self.should_receive(:sortable_header).with(grid, col, {}) { tracer }
      self.should_receive(:sortable_header) { tracer }
      magic_headers(grid).should include(tracer)
    end
  end

  describe "#search_bar" do
    searchable_opts = { needs_searcher: true }
    it "renders a search field" do
      cols = [:some_col]
      grid = MagicGrid::Definition.new(cols, nil, nil, searchable_opts)
      search_bar(grid).should match_select("input[type=search]")
    end
    it "renders a search button if told to" do
      tracer = "ZOMG! A BUTTON!"
      cols = [:some_col]
      opts = searchable_opts.merge(search_button: true,
                                   searcher_button: tracer)
      grid = MagicGrid::Definition.new(cols, nil, nil, opts)
      search_bar(grid).should match_select("button", text: tracer)
    end
  end

  describe "column sorting helpers" do
    it "#reverse_order" do
      reverse_order(0).should == 1
      reverse_order(1).should == 0
      reverse_order(2).should == 0
    end
    it "#order_icon" do
      order_icon(0).should match_select('span.ui-icon-triangle-1-n')
      order_icon(1).should match_select('span.ui-icon-triangle-1-s')
      order_icon(2).should match_select('span.ui-icon-carat-2-n-s')
    end
    it "#order_class" do
      order_class(0).should == 'sort-asc'
      order_class(1).should == 'sort-desc'
      order_class(2).should == 'sort-none'
    end
  end

end
