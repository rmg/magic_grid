require 'spec_helper'
require 'magic_grid/helpers'
require 'action_controller'

describe MagicGrid::Helpers do

	# Let's use the helpers the way they're meant to be used!
	include MagicGrid::Helpers

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
end
