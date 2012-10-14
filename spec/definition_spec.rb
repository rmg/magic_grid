require 'spec_helper'
require 'magic_grid/definition'
require 'active_support/core_ext/hash/indifferent_access'

describe MagicGrid::Definition do
  pending "embarasses me with how tightly it is coupled with.. EVERYTHING"

  shared_examples "a basic grid" do
    its(:options) { should == MagicGrid::Definition.runtime_defaults }
    its(:current_page) { should == 1 }

    descendings = [1, "1", :desc, :DESC, "desc", "DESC"]
    descendings.each do |down|
      it "should normalize #{down} to 1" do
        expect(subject.order(down)).to eq(1)
      end
    end

    ascendings = [0, "0", :asc, :ASC, "asc", "ASC"]
    ascendings.each do |up|
      it "should normalize #{up} to 0" do
        expect(subject.order(up)).to eq(0)
      end
    end
  end

  let (:empty_collection) { [] }
  let (:large_collection) { 200.times.map { |i| {id: i, name: "Name", description: "Describe me!"} } }
  let (:column_list) { [:name, :description] }
  let (:column_hash) { {} }

  it "can be initialized with a list of columns" do
    expect {
      MagicGrid::Definition.new(column_list, empty_collection)
    }.not_to raise_error
  end

  it "can be initialized with an option hash" do
    expect {
      MagicGrid::Definition.new(column_hash, empty_collection)
    }.not_to raise_error
  end

  it "barfs when you don't give it what it wants" do
    expect { MagicGrid::Definition.new() }.to raise_error
  end

  context "when given an empty collection" do
    subject { MagicGrid::Definition.new(column_list, empty_collection) }
    its(:base_params) { should include(:magic_grid_id) }
    its(:collection) { should == empty_collection }
    its(:columns) { should == column_list }
    it_behaves_like "a basic grid"
  end

  context "when given a large collection and default options" do
    let(:controller) {
      controller = double()
      controller.stub(:params) { {page: 2} }
      controller
    }
    subject { MagicGrid::Definition.new(column_list, large_collection, controller) }
    it_behaves_like "a basic grid"
    its(:collection) { should_not == empty_collection }

    its(:collection) { should have(MagicGrid::Definition.runtime_defaults[:per_page]).items }
    its(:columns) { should == column_list }
  end

  context "when given a MagicGrid::Collection" do
    actual_collection = [1,2,3]
    let(:collection) { MagicGrid::Collection.new(actual_collection, nil) }
    subject { MagicGrid::Definition.new(column_list, collection, controller) }
    its(:collection) { should eq(actual_collection) }
  end

  context "when given a large collection and some options" do
    let(:controller) {
      controller = double()
      controller.stub(:params) { HashWithIndifferentAccess.new({grid_page: 2}) }
      controller
    }
    subject { MagicGrid::Definition.new(column_list, large_collection, controller, id: :grid, per_page: 17) }
    its(:collection) { should_not == empty_collection }
    it "should give a collection with a page worth of items" do
      subject.per_page.should < large_collection.count
      subject.collection.should have(subject.per_page).items
    end
    its(:columns) { should == column_list }
    its(:current_page) { should == 2 }

    it "should know how to extract its params" do
      subject.param_key(:page).should == :grid_page
      subject.param_key(:hunkydory).should == :grid_hunkydory
      subject.param(:page).should == 2
    end
  end

  context "sorting" do
    data = [1,56,7,21,1]
    let(:controller) {
      controller = double()
      controller.stub(:params) { HashWithIndifferentAccess.new({grid_order: 1}) }
      controller
    }
    let(:collection) {
      data.tap do |d|
        d.stub(:order) do |col, dir|
          dir == "ASC" ? d.sort : d.sort.reverse
        end
      end
    }
    subject { MagicGrid::Definition.new([{:sql => "foo"}], collection, controller, id: :grid) }
    its(:collection) { should == data.sort.reverse }

    # pending "sorting needs testing"
    # pending "test #order_sql"
  end
  context "filtering" do
    data = [1,56,7,21,1]
    let(:controller) {
      controller = double.tap do |c|
        c.stub(:params) { HashWithIndifferentAccess.new({f1: 1}) }
      end
    }
    let(:collection) {
      data.tap do |d|
        d.stub(:where) do |h|
          d.select { |d| d < 10 }
        end
      end
    }
    subject { MagicGrid::Definition.new([{:sql => "foo"}],
                                        collection,
                                        controller,
                                        id: :grid, listeners: {f1: :f1}) }
    its(:collection) { should == [1, 7, 1] }

    pending "test listeners"
    pending "test listener_handlers"
    pending "test listening on a dumb collection"
    pending "test callable post_filter"
    pending "test collection post_filter"
  end
end
