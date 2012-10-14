require 'spec_helper'
require 'magic_grid/collection'

describe MagicGrid::Collection do

  context "via [] class method" do
    let(:actual_collection) { [1,2,3,4] }
    let(:magic_collection) { MagicGrid::Collection.new(actual_collection, :original_grid) }
    subject { MagicGrid::Collection[magic_collection, :new_grid] }
    its(:collection) { should eq(actual_collection) }
    its(:grid) { should eq(:new_grid) }
  end

  context "when based on an array" do
    let(:collection) { [1,2,3,4] }
    subject { MagicGrid::Collection.new(collection, nil) }
    its(:collection) { should eq(collection) }
    its(:grid) { should be_nil }
  end
end