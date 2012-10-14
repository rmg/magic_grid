require 'spec_helper'
require 'magic_grid/helpers'
require 'action_controller'
require "active_support/core_ext"

def make_controller
  request = double.tap{ |r|
    r.stub(:fullpath, "/foo?page=bar")
  }
  double.tap { |v|
    v.stub(:render) { nil }
    v.stub(:params) { {} }
    v.stub(:request) { request }
  }
end

def fake_connection
  double(:connection).tap do |c|
    c.stub(:quote_column_name) { |col| col.to_s }
  end
end

def fake_active_record_collection(table_name = 'some_table')
  (1..1000).to_a.tap do |c|
    c.stub(:connection => fake_connection)
    c.stub(:table_name => table_name)
    c.stub(:where) { c }
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

    context "searching" do
      let(:search_param) { 'foobar' }
      let(:searchabe_collection) {
        collection = []
        collection.stub(:search)
        collection
      }
      let(:controller) {
        make_controller.tap { |c|
          c.stub(:params) { {:grid_id_q => search_param} }
        }
      }

      it "should render a search bar when asked" do
        grid = magic_grid(searchabe_collection, column_list, :searchable => [:some_col])
        grid.should match_select('input[type=search]')
      end

      it "should search a searchable collection when there are search params" do
        collection = (1..1000).to_a
        collection.should_receive(:search).with(search_param) { collection }
        grid = magic_grid(collection, column_list, :id => "grid_id", :searchable => [:some_col])
        grid.should match_select('input[type=search]')
      end

      context "when the collection responds to #where" do
        it "should call where when there are search params" do
          search_col = :some_col
          table_name = "tbl"
          search_sql = "tbl.some_col"

          collection = fake_active_record_collection(table_name)
          collection.should_receive(:where).
                     with("#{search_sql} LIKE :search", {:search=>"%#{search_param}%"})

          grid = magic_grid(collection, column_list, :id => "grid_id", :searchable => [search_col])
        end

        it "should use custom sql from column for call to where when given" do
          search_col = :some_col
          search_sql = "sql that doesn't necessarily match column name"
          table_name = "table name not used in query"

          collection = fake_active_record_collection(table_name)
          collection.should_receive(:where).
                     with("#{search_sql} LIKE :search", {:search=>"%#{search_param}%"})

          magic_grid(collection,
                     [ :name,
                       :description,
                       {:col => search_col, :sql => search_sql}
                       ],
                     :id => "grid_id", :searchable => [search_col])
        end

        it "should use column number to look up search column" do
          search_col = :some_col
          search_sql = "sql that doesn't necessarily match column name"
          table_name = "table name not used in query"

          collection = fake_active_record_collection(table_name)
          collection.should_receive(:where).
                     with("#{search_sql} LIKE :search", {:search=>"%#{search_param}%"})

          magic_grid(collection,
                     [ :name,
                       :description,
                       {:col => search_col, :sql => search_sql}
                       ],
                     :id => "grid_id", :searchable => [2])
        end

        it "should use custom sql for call to where when given" do
          search_col = :some_col
          custom_search_col = "some custom search column"
          search_sql = custom_search_col
          table_name = "table name not used in query"

          collection = fake_active_record_collection(table_name)
          collection.should_receive(:where).
                     with("#{search_sql} LIKE :search", {:search=>"%#{search_param}%"})

          magic_grid(collection,
                     [ :name,
                       :description,
                       {:col => search_col, :sql => search_sql}
                       ],
                     :id => "grid_id", :searchable => [custom_search_col])
        end

        it "should fail when given bad searchable columns" do
          collection = fake_active_record_collection()
          collection.should_not_receive(:where)

          expect {
            magic_grid(collection,
                       [ :name, :description],
                       :id => "grid_id", :searchable => [nil])
          }.to raise_error
        end

        it "should not fail if #where fails" do
          search_col = :some_col
          table_name = "tbl"
          search_sql = "tbl.some_col"

          collection = fake_active_record_collection(table_name)
          magic_collection = MagicGrid::Collection.new(collection, nil)
          collection.should_receive(:where).and_raise("some failure")
          # magic_collection.logger = double.tap do |l|
          #   l.should_receive(:debug)
          # end

          expect {
            magic_grid(collection, column_list, :id => "grid_id", :searchable => [search_col])
          }.to_not raise_error
        end
      end
    end
  end

end
