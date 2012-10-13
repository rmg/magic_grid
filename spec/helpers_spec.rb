require 'spec_helper'
require 'magic_grid/helpers'
require 'action_controller'
require "active_support/core_ext"

describe MagicGrid::Helpers do

  # Let's use the helpers the way they're meant to be used!
  include MagicGrid::Helpers

  let(:empty_collection) { [] }

  let(:column_list) { [:name, :description] }

  let(:controller) {
    request = double.tap{ |r|
      r.stub(:fullpath, "/foo?page=bar")
    }
    double.tap { |v|
      v.stub(:render) { nil }
      v.stub(:params) { {} }
      v.stub(:request) { request }
    }
  }

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
    let(:searchabe_collection) {
      collection = []
      collection.stub(:search)
      collection
    }

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

    it "should render a search bar when asked" do
      grid = magic_grid(searchabe_collection, column_list, :searchable => [:some_col])
      grid.should match_select('input[type=search]')
    end
  end

end
