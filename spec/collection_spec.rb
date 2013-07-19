require 'spec_helper'
require 'magic_grid/collection'
require 'magic_grid/column'

describe MagicGrid::Collection do

  context "via [] class method" do
    context "when given a MagicGrid::Collection" do
      let(:actual_collection) { [1,2,3,4] }
      let(:magic_collection) { MagicGrid::Collection.new(actual_collection) }
      subject { MagicGrid::Collection.create_or_reuse(magic_collection) }
      its(:collection) { should eq(actual_collection) }
    end
    context "when given a basic collection" do
      let(:actual_collection) { [1,2,3,4] }
      subject { MagicGrid::Collection.create_or_reuse(actual_collection) }
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

  describe "#perform_search" do
    context "when the collection is searchable" do
      let(:collection) {
        fake_active_record_collection('some_table', [:name, :description])
      }
      subject {
        MagicGrid::Collection.new(collection).tap do |c|
          c.searchable_columns = [MagicGrid::FilterOnlyColumn.new(:name, c)]
        end
      }
      it { subject.should be_filterable }
      it { subject.should be_searchable }
      it "should apply a search query when given one" do
        subject.apply_search("foobar")
        subject.searches.should_not be_empty
      end
      it "should not barf when given a blank search query" do
        subject.apply_search(nil)
        subject.apply_search("")
        subject.searches.should be_empty
      end
    end

    context "when the collection is not searchable" do
      let(:collection) {
        fake_active_record_collection('some_table', [:name, :description])
      }
      subject { MagicGrid::Collection.new(collection) }
      it { subject.should be_filterable }
      it { subject.should_not be_searchable }
      it "should not apply a search query when given one" do
        subject.apply_search("foobar")
        subject.searches.should be_empty
      end
      it "should not barf when given a blank search query" do
        subject.apply_search(nil)
        subject.apply_search("")
        subject.searches.should be_empty
      end
    end
  end

  describe "pagination" do
    context "#calculate_total_pages" do
      let(:array) { Array.new(10) { 1 }  }
      subject { MagicGrid::Collection.new(array, nil) }
      it "should round correctly" do
        subject.calculate_total_pages(2, 10).should == 5
        subject.calculate_total_pages(3, 10).should == 4
        subject.calculate_total_pages(4, 10).should == 3
      end
    end

    context "#bound_current_page" do
      let(:array) { Array.new(10) { 1 }  }
      subject { MagicGrid::Collection.new(array, nil) }

      it "should round page 0 correctly" do
        subject.bound_current_page(0, 2, 10).should == 1
        subject.bound_current_page(0, 3, 10).should == 1
        subject.bound_current_page(0, 4, 10).should == 1
      end

      it "should round page > pages correctly" do
        subject.bound_current_page(10, 2, 10).should == 5
        subject.bound_current_page(10, 3, 10).should == 4
        subject.bound_current_page(10, 4, 10).should == 3
      end
    end
  end

  describe "#perform_pagination" do

    context "page counts" do
      let(:array) { Array.new(100) { 1 } }
      subject { MagicGrid::Collection.new(array, nil) }

      it "should correctly calculate uneven page splits" do
        subject.per_page = 33
        subject.total_pages.should == 4
      end

      it "should correctly calculate even page splits" do
        subject.per_page = 20
        subject.total_pages.should == 5
      end
    end

    context "page bounds checks" do
      let(:array) { (1..10).to_a }
      subject { MagicGrid::Collection.new(array, nil) }

      it "should round down to the last page if a later page is requested" do
        subject.per_page = 3
        subject.total_pages.should == 4
        subject.apply_pagination(5)
        subject.perform_pagination(array)
        subject.current_page.should == 4
      end

      context "providing the correct data" do
        before(:each) { subject.per_page = 3 }
        it "handles pages beyond lower bound" do
          subject.apply_pagination(0)
          subject.perform_pagination(array).should == [1,2,3]
        end
        it "handles pages in bounds" do
          subject.apply_pagination(1)
          subject.perform_pagination(array).should == [1,2,3]
          subject.apply_pagination(2)
          subject.perform_pagination(array).should == [4,5,6]
          subject.apply_pagination(3)
          subject.perform_pagination(array).should == [7,8,9]
          subject.apply_pagination(4)
          subject.perform_pagination(array).should == [10]
        end
        it "handles pages above bounds" do
          subject.apply_pagination(5)
          subject.perform_pagination(array).should == [10]
        end
      end
    end

  #TODO these tests will only really work properly once we have the ability
  #     to undefine constants, which looks like it should be coming in a future
  #     version of RSpec (as in post 2.11.1)

    context "when #paginate (aka WillPaginate) is available" do
      it "should call paginate helper when it is detected" do
        array = [1].tap do |a|
          a.should_receive(:paginate).with(:page => 1, :per_page => 1,
                                           :total_entries => 1) { a }
        end
        collection = MagicGrid::Collection.new(array, nil)
        collection.per_page = 1
        collection.apply_pagination 1
        collection.perform_pagination(array).should == array
      end
    end

    unless $will_paginate
      context "when #page (possibly from Kaminari) is available" do
        it "should call paginate helper when it is detected" do
          array = [1].tap do |a|
            a.should_receive(:per).with(1).and_return(a)
            a.should_receive(:page).with(1).and_return(a)
          end
          collection = MagicGrid::Collection.new(array, nil)
          collection.per_page = 1
          collection.apply_pagination 1
          collection.perform_pagination(array).should == array
        end
      end

      unless $kaminari
        context "when given an Array and Kaminari is available" do
          it "should call paginate helper when it is detected" do
            array = Array.new(10) { 1 }
            kaminaried_array = [1].tap do |ka|
              ka.should_receive(:per).with(1).and_return(ka)
              ka.should_receive(:page).with(1).and_return(ka)
            end
            kaminari = double.tap do |k|
              k.should_receive(:paginate_array).with(array).and_return(kaminaried_array)
            end
            collection = MagicGrid::Collection.new(array, nil)
            collection.per_page = 1
            collection.apply_pagination 1
            old_kaminari = MagicGrid::Collection.kaminari_class
            MagicGrid::Collection.kaminari_class = kaminari
            collection.perform_pagination(array).should == kaminaried_array
            MagicGrid::Collection.kaminari_class = old_kaminari
          end
        end
      end
    end

    context "when no pagination is provided" do
      # TODO replace this when rspec-mocks add 'hide_const'
      # before :each do
      #   if defined?(Kaminari)
      #     @kaminari = Module.const_get(:Kaminari)
      #     Object.send(:remove_const, :Kaminari)
      #   end
      # end
      # after :each do
      #   Module.const_set(:Kaminari, @kaminari) if @kaminari
      # end

      #
      #  For now, Travis-CI takes care of this, since we have gem profiles defined
      #  to test all 3 supported pagination scenarios
      #

      it "should attempt to use Enumerable methods to perform pagination" do
        array = Array.new(100) { 1 }
        collection = MagicGrid::Collection.new(array, nil)
        collection.per_page = 1
        collection.apply_pagination 1
        collection.perform_pagination(array).should == [1]
      end
    end
  end
end
