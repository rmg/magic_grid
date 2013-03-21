require 'spec_helper'
require 'magic_grid/order'

describe MagicGrid::Order do
  describe "#from_param" do
    it { MagicGrid::Order.from_param(1).should == MagicGrid::Order::Descending }
  end
end
