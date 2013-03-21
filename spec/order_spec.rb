require 'spec_helper'
require 'magic_grid/order'

describe MagicGrid::Order do
  describe '#from_param' do
    it { MagicGrid::Order.from_param(0).should == MagicGrid::Order::Ascending }
    it { MagicGrid::Order.from_param(1).should == MagicGrid::Order::Descending }
    it { MagicGrid::Order.from_param(2).should == MagicGrid::Order::Ascending }
  end
  describe '#css_class' do
    it { MagicGrid::Order::Unordered.css_class.should == 'sort-none' }
    it { MagicGrid::Order::Ascending.css_class.should == 'sort-asc' }
    it { MagicGrid::Order::Descending.css_class.should == 'sort-desc' }
  end
  describe '#icon_class' do
    it { MagicGrid::Order::Unordered.icon_class.should == 'ui-icon-carat-2-n-s' }
    it { MagicGrid::Order::Ascending.icon_class.should == 'ui-icon-triangle-1-n' }
    it { MagicGrid::Order::Descending.icon_class.should == 'ui-icon-triangle-1-s' }
  end
  describe '#to_sql' do
    it { MagicGrid::Order::Unordered.to_sql.should == 'ASC' }
    it { MagicGrid::Order::Ascending.to_sql.should == 'ASC' }
    it { MagicGrid::Order::Descending.to_sql.should == 'DESC' }
  end
  describe '#reverse' do
    it { MagicGrid::Order::Unordered.reverse.should == MagicGrid::Order::Descending }
    it { MagicGrid::Order::Ascending.reverse.should == MagicGrid::Order::Descending }
    it { MagicGrid::Order::Descending.reverse.should == MagicGrid::Order::Ascending }
  end
end
