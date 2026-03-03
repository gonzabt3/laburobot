require "test_helper"

class CategoryNormalizeServiceTest < ActiveSupport::TestCase
  test "returns catalog key for direct match" do
    assert_equal "plomeria", CategoryNormalizeService.normalize("plomeria")
  end

  test "maps keyword to category" do
    assert_equal "electricidad", CategoryNormalizeService.normalize("electricista")
  end

  test "returns 'otro' for unknown term" do
    assert_equal "otro", CategoryNormalizeService.normalize("xyzabc123")
  end

  test "returns 'otro' for blank input" do
    assert_equal "otro", CategoryNormalizeService.normalize("")
    assert_equal "otro", CategoryNormalizeService.normalize(nil)
  end

  test "is case insensitive" do
    assert_equal "plomeria", CategoryNormalizeService.normalize("PLOMERO")
  end
end
