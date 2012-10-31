require 'spec_helper'
require 'magic_grid/collection'

describe MagicGrid::Collection do

  context "via [] class method" do
    context "when given a MagicGrid::Collection" do
      let(:actual_collection) { [1,2,3,4] }
      let(:magic_collection) { MagicGrid::Collection.new(actual_collection, :original_grid) }
      subject { MagicGrid::Collection[magic_collection, :new_grid] }
      its(:collection) { should eq(actual_collection) }
    end
    context "when given a basic collection" do
      let(:actual_collection) { [1,2,3,4] }
      subject { MagicGrid::Collection[actual_collection, :original_grid] }
      its(:collection) { should eq(actual_collection) }
    end
  end

  context "when based on an array" do
    let(:collection) { [1,2,3,4] }
    subject { MagicGrid::Collection.new(collection, nil) }
    its(:collection) { should eq(collection) }
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
      column = MagicGrid::FilterOnlyColumn.new("col")
      collection.apply_sort(column, "order")
      collection.collection.should == ordered
    end
  end

  context "when post filter callback is given" do
    it "should call the given callback when the collection is reduced" do
      array = [1]
      callback = double.tap do |cb|
        cb.should_receive(:call).with(array) { [2] }
      end
      collection = MagicGrid::Collection.new(array, nil)
      collection.add_post_filter_callback(callback)
      collection.collection.should == [2]
    end
  end

  #TODO these tests will only really work properly once we have the ability
  #     to undefine constants

  describe "#perform_pagination" do

    context "when #paginate (aka WillPaginate) is available" do
      it "should call paginate helper when it is detected" do
        array = [1].tap do |a|
          a.should_receive(:paginate).with(page: 1, per_page: 1) { a }
        end
        collection = MagicGrid::Collection.new(array, nil)
        collection.apply_pagination(1, 1)
        collection.perform_pagination(array).should == array
      end
    end

    unless Module.const_defined? :WillPaginate
      context "when #page (possibly from Kaminari) is available" do
        it "should call paginate helper when it is detected" do
          array = [1].tap do |a|
            a.should_receive(:per).with(1) { array }
            a.should_receive(:page).with(1) { array }
          end
          collection = MagicGrid::Collection.new(array, nil)
          collection.apply_pagination(1, 1)
          collection.perform_pagination(array).should == array
        end
      end

      context "when given an Array and Kaminari is available" do
        it "should call paginate helper when it is detected" do
          array = Array.new(10) { 1 }
          kaminaried_array = [1,1].tap do |ka|
            ka.should_receive(:per).with(1) { ka }
            ka.should_receive(:page).with(1) { ka }
          end
          kaminari = double.tap do |k|
            k.should_receive(:paginate_array).with(array) { kaminaried_array }
          end
          stub_const('Kaminari', kaminari)
          collection = MagicGrid::Collection.new(array, nil)
          collection.apply_pagination(1, 1)
          collection.perform_pagination(array).should == kaminaried_array
        end
      end
    end

    context "when no pagination is provided" do
      # TODO replace this when rspec-mocks add 'hide_const'
      # before :each do
      #   if Module.const_defined?(:Kaminari)
      #     @kaminari = Module.const_get(:Kaminari)
      #     Object.send(:remove_const, :Kaminari)
      #   end
      # end
      # after :each do
      #   Module.const_set(:Kaminari, @kaminari) if @kaminari
      # end

      it "should attempt to use Enumerable methods to perform pagination" do
        array = Array.new(100) { 1 }
        collection = MagicGrid::Collection.new(array, nil)
        collection.apply_pagination(1, 1)
        collection.perform_pagination(array).should == [1]
      end
    end
  end
end
