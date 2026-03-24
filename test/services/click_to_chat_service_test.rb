require "test_helper"

class ClickToChatServiceTest < ActiveSupport::TestCase
  test "builds whatsapp URL with phone and message" do
    url = ClickToChatService.whatsapp(phone: "+5491112345678", message: "Hola mundo")
    assert_equal "https://wa.me/5491112345678?text=Hola+mundo", url
  end

  test "builds whatsapp URL without message" do
    url = ClickToChatService.whatsapp(phone: "+5491112345678")
    assert_equal "https://wa.me/5491112345678", url
  end

  test "strips leading + from phone" do
    url = ClickToChatService.whatsapp(phone: "+5491199999999")
    assert url.start_with?("https://wa.me/5491199999999")
  end

  test "builds telegram URL with username" do
    url = ClickToChatService.telegram(username: "johndoe")
    assert_equal "https://t.me/johndoe", url
  end

  test "builds telegram URL with username and message" do
    url = ClickToChatService.telegram(username: "johndoe", message: "Hola")
    assert_equal "https://t.me/johndoe?start=Hola", url
  end

  test "raises error without username or phone" do
    assert_raises(ArgumentError) { ClickToChatService.telegram }
  end
end
