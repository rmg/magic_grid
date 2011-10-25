require 'test_helper'

class MagicGridTest < ActiveSupport::TestCase
  test "Module definition" do
    assert_kind_of Module, MagicGrid
  end
  test "Class definition" do
    assert_kind_of Class, MagicGrid::MagicGridHelpers::MagicGrid
  end
  test "ActionView extension" do
    assert_kind_of Module, ActionView::Helpers::MagicGridHelpers
    assert_kind_of Class, ActionView::Helpers::MagicGridHelpers::MagicGrid
  end
end
