require 'spec_helper'
require 'magic_grid/helpers'

describe MagicGrid::Helpers do

  # Let's use the helpers the way they're meant to be used!
  include MagicGrid::Helpers

  let(:empty_collection) { [] }
  let(:column_list) { [:name, :description] }
  let(:controller) { make_controller }

  # Kaminari uses view_renderer instead of controller
  let(:view_renderer) { controller }

  describe "#magic_grid" do
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
      it { should  match_select("td", text: "1") }
      it { should  match_select("td", text: "2") }
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

    context "searching and paging" do
      let(:searchabe_collection) {
        collection = [].tap do |c|
          c.stub(:search) { collection }
        end
      }
      it "should only render one spinner" do
        grid = magic_grid(searchabe_collection, column_list, searchable: [:some_col])
        grid.should match_select("td.searcher", 1)
        grid.should match_select("td.magic-pager", 1)
        grid.should match_select(".magic_grid_spinner", 1)
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
      let(:sortable_collection) { fake_active_record_collection }
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

end
