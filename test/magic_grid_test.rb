require 'test_helper'

class MagicGridTest < ActiveSupport::TestCase
  test "Module definition" do
    assert_kind_of Module, MagicGrid
    assert_kind_of Module, MagicGrid::MagicGridHelpers
  end
  test "Class definition" do
    assert_kind_of Class, MagicGrid::MagicGridHelpers::MagicGrid
  end
end
