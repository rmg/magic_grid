require 'spec_helper'
require 'magic_grid/column'
require 'magic_grid/collection'

describe MagicGrid::Column do
  describe "Column.columns_for_collection" do
    let(:collection) { MagicGrid::Collection.new([]) }
    context "for setting searchable columns on collection" do
      it "enables searching on non-displayed columns" do
        display = [:name]
        searchable = [:secret]
        columns = MagicGrid::Column.columns_for_collection(collection, display, searchable)
        collection.searchable_columns.count.should == 1
      end
      it "enables searching on displayed columns" do
        display = [:name]
        searchable = [:name]
        columns = MagicGrid::Column.columns_for_collection(collection, display, searchable)
        collection.searchable_columns.count.should == 1
      end
      it "disables searching when told so" do
        display = [:name]
        searchable = false
        columns = MagicGrid::Column.columns_for_collection(collection, display, searchable)
        collection.searchable_columns.should be_empty
      end
    end
  end
end