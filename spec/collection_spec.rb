require 'spec_helper'
require 'magic_grid/collection'

describe MagicGrid::Collection do

  context "via [] class method" do
    context "when given a MagicGrid::Collection" do
      let(:actual_collection) { [1,2,3,4] }
      let(:magic_collection) { MagicGrid::Collection.new(actual_collection, :original_grid) }
      subject { MagicGrid::Collection[magic_collection, :new_grid] }
      its(:collection) { should eq(actual_collection) }
      its(:grid) { should eq(:new_grid) }
    end
    context "when given a basic collection" do
      let(:actual_collection) { [1,2,3,4] }
      subject { MagicGrid::Collection[actual_collection, :original_grid] }
      its(:collection) { should eq(actual_collection) }
      its(:grid) { should eq(:original_grid) }
    end
  end

  context "when based on an array" do
    let(:collection) { [1,2,3,4] }
    subject { MagicGrid::Collection.new(collection, nil) }
    its(:collection) { should eq(collection) }
    its(:grid) { should be_nil }
  end

  context "when based on something sortable" do
    data = [1,5,3,2,56,7]
    let(:sortable_collection) {
      data.tap do |d|
        d.stub(:order) { d }
      end
    }
    it "should send #order when sorted" do
      ordered = [1,2,3,4,5]
      collection = MagicGrid::Collection.new(sortable_collection, nil)
      sortable_collection.should_receive(:order) { ordered }
      collection.apply_sort("col", "order")
      collection.collection.should == ordered
    end
  end
end