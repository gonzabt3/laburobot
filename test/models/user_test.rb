require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with phone_e164 and role" do
    user = User.new(phone_e164: "+5491100000001", role: :client)
    assert user.valid?
  end

  test "invalid without phone_e164" do
    user = User.new(role: :client)
    assert_not user.valid?
    assert_includes user.errors[:phone_e164], "can't be blank"
  end

  test "invalid with malformed phone_e164" do
    user = User.new(phone_e164: "1234567890", role: :client)
    assert_not user.valid?
    assert_includes user.errors[:phone_e164], "is invalid"
  end

  test "accepts telegram-style synthetic identifier" do
    user = User.new(phone_e164: "+tg123456789", role: :client)
    assert user.valid?
  end

  test "invalid without role" do
    user = User.new(phone_e164: "+5491100000002")
    assert_not user.valid?
  end

  test "phone_e164 must be unique" do
    User.create!(phone_e164: "+5491100000003", role: :client)
    dup = User.new(phone_e164: "+5491100000003", role: :provider)
    assert_not dup.valid?
    assert_includes dup.errors[:phone_e164], "has already been taken"
  end

  test "defaults status to active" do
    user = User.new(phone_e164: "+5491100000004", role: :client)
    user.valid?
    assert_equal "active", user.status
  end

  test "valid roles" do
    assert User.new(phone_e164: "+5491100000005", role: :client).valid?
    assert User.new(phone_e164: "+5491100000006", role: :provider).valid?
  end
end
