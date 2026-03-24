require "test_helper"

class RateLimitServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(phone_e164: "+5491155556666", role: :client)
    @provider = User.create!(phone_e164: "+5491155557777", role: :provider)
    @service_request = ServiceRequest.create!(
      client_user: @user,
      category: "plomeria",
      details: "Need a plumber"
    )
  end

  test "allows first contact delivery" do
    result = RateLimitService.check(user: @user, service_request: @service_request)
    assert result.allowed?
  end

  test "blocks after max leads per request" do
    # Create leads with timestamps past the cooldown window
    RateLimitService::MAX_LEADS_PER_REQUEST.times do |i|
      prov = User.create!(phone_e164: "+549115555#{7800 + i}", role: :provider)
      lead = Lead.create!(
        service_request: @service_request,
        provider_user: prov,
        delivered_at: 2.minutes.ago
      )
      lead.update_column(:created_at, 2.minutes.ago)
    end
    result = RateLimitService.check(user: @user, service_request: @service_request)
    assert_not result.allowed?
    assert_match(/máximo/, result.message)
  end

  test "enforces cooldown between consecutive contacts" do
    prov = User.create!(phone_e164: "+5491155558888", role: :provider)
    Lead.create!(service_request: @service_request, provider_user: prov, delivered_at: Time.current)

    result = RateLimitService.check(user: @user, service_request: @service_request)
    assert_not result.allowed?
    assert result.wait_seconds > 0
  end

  test "blocks after daily cap" do
    RateLimitService::MAX_LEADS_PER_DAY.times do |i|
      sr = ServiceRequest.create!(client_user: @user, category: "limpieza", details: "test #{i}")
      prov = User.create!(phone_e164: "+549115555#{9000 + i}", role: :provider)
      Lead.create!(
        service_request: sr,
        provider_user: prov,
        delivered_at: 2.minutes.ago
      )
    end

    new_sr = ServiceRequest.create!(client_user: @user, category: "pintura", details: "new request")
    result = RateLimitService.check(user: @user, service_request: new_sr)
    assert_not result.allowed?
    assert_match(/diario/, result.message)
  end
end
