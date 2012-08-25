require 'spec_helper'
require 'magic_grid/helpers'
require 'action_controller'

describe MagicGrid::Helpers do

	# Let's use the helpers the way they're meant to be used!
	include MagicGrid::Helpers

	let(:empty_collection) { [] }
	let(:column_list) { [:name, :description] }

	let(:controller) {
		stub_controller = ActionController::Base.new
		def stub_controller.params(*ignored) {} end
		stub_controller
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
	end

end
