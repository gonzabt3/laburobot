require "test_helper"

class ProviderProfileTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(phone_e164: "+5491122334455", role: :provider)
  end

  test "valid with required attributes" do
    profile = ProviderProfile.new(user: @user, service_area_type: :nationwide)
    assert profile.valid?
  end

  test "invalid without user" do
    profile = ProviderProfile.new(service_area_type: :nationwide)
    assert_not profile.valid?
  end

  test "categories_list round-trips correctly" do
    profile = ProviderProfile.new(user: @user, service_area_type: :nationwide)
    profile.categories_list = %w[plomeria electricidad]
    assert_equal %w[plomeria electricidad], profile.categories_list
  end

  test "active defaults to true" do
    profile = ProviderProfile.new(user: @user, service_area_type: :nationwide)
    profile.valid?
    assert_equal true, profile.active
  end
end
