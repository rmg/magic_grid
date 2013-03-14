require 'spec_helper'
require 'magic_grid/column'
require 'magic_grid/collection'

describe MagicGrid::Column do
  describe "Column.columns_for_collection" do
    context "for setting searchable columns on column filtering collection" do
      let(:collection_backing) { fake_active_record_collection }
      let(:collection) { MagicGrid::Collection.new(collection_backing) }
      it "enables searching on non-displayed columns" do
        display = [:name]
        searchable = [:secret]
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should be_searchable
      end
      it "enables searching on displayed columns" do
        display = [:name]
        searchable = [:name]
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should be_searchable
      end
      it "accepts false as a method of disabling search" do
        display = [:name]
        searchable = false
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should_not be_searchable
      end
      it "doesn't enable searching when not given a column" do
        display = [:name]
        searchable = true
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should_not be_searchable
      end
    end
    context "for enabling/disabling search on #search() style collection" do
      let(:collection) {
        data = [1,2,3].tap do |c|
          c.stub(:search) { c }
        end
        MagicGrid::Collection.new(data, :search_method => :search)
      }
      # I actually consider this a bug, since it is totally inconsistent, but
      # it's how things are currently implemented.
      it "doesn't disable searching, even when told so" do
        display = [:name]
        searchable = false
        collection.should be_searchable
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should be_searchable
      end
      it "enables searching when told so" do
        collection.should be_searchable
        display = [:name]
        searchable = true
        columns = MagicGrid::Column.columns_for_collection(collection,
                                                           display,
                                                           searchable)
        collection.should be_searchable
      end
    end
  end
end