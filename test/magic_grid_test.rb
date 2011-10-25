require 'test_helper'

class MagicGridTest < ActiveSupport::TestCase
  test "Module definition" do
    assert_kind_of Module, MagicGrid::Helpers
  end
  test "Class definition" do
    assert_kind_of Class, MagicGrid
  end
end
