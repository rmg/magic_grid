require 'spec_helper'
require 'magic_grid/definition'

describe MagicGrid::Definition do
	let (:empty_collection) { [] }
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

	subject { MagicGrid::Definition.new(column_list, empty_collection) }
	its(:base_params) { should_not be_nil }
	its(:collection) { should == empty_collection }
	its(:columns) { should == column_list }
	its(:options) { should == MagicGrid::Definition.runtime_defaults }


	descendings = [1, "1", :desc, :DESC, "desc", "DESC"]
	descendings.each do |down|
		it "should normalize #{down} to 1" do
			expect(subject.order(down)).to eq(1)
		end
	end

	ascendings = [0, "0", :asc, :ASC, "dasc", "ASC"]
	ascendings.each do |up|
		it "should normalize #{up} to 0" do
			expect(subject.order(up)).to eq(0)
		end
	end


end