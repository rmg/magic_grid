require 'spec_helper'
require 'magic_grid/helpers'
require 'action_controller'

describe MagicGrid::Helpers do

  # Let's use the helpers the way they're meant to be used!
  include MagicGrid::Helpers

  let(:empty_collection) { [] }
  let(:column_list) { [:name, :description] }

  let(:view_renderer) {
    double.tap { |v|
      v.stub(:render)
      v.stub(:params) { {} }
      # controller.stub(:option)
      v.stub(:url_for) {|h| "/foo?page=#{h[:page]}"}
    }
  }

  describe "#normalize_magic" do

    it "should turn an array into a MagicGrid::Definition" do
      expect(normalize_magic([])).to be_a(MagicGrid::Definition)
    end

    it "should give back the MagicGrid::Definition given, if given one" do
      definition = normalize_magic([])
      expect(normalize_magic(definition)).to be(definition)
    end
  end

  describe "#magic_collection" do
    pending "should probably be removed, it's not really used"

    it "should give back a collection like the one given" do
      my_empty_collection = empty_collection
      expect(magic_collection(my_empty_collection, column_list)).to eq(my_empty_collection)
    end

  end

  describe "#magic_grid" do
    pending "DOES WAY TOO MUCH!!"

    it "should barf without any arguments" do
      expect { magic_grid }.to raise_error
    end

    let(:emtpy_grid) { magic_grid empty_collection, column_list }

    it "should render a table" do
      expect( emtpy_grid ).not_to be_empty
      expect( emtpy_grid ).to match(/<\/table>/)
    end

    context "when given an empty collection" do
      let(:empty_grid) { magic_grid(empty_collection, column_list) }
      it "should indicate there is no data" do
        expect(empty_grid).to match(/"if-empty"/)
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
  end

end
