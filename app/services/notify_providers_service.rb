# NotifyProvidersService: sends notifications to matching providers for a service request.
#
# Uses SearchProvidersService to find providers, then sends each one a Telegram/WhatsApp
# message about the new request and creates a Lead record to track the notification.
#
# Usage:
#   NotifyProvidersService.call(service_request)
class NotifyProvidersService
  MAX_PROVIDERS_TO_NOTIFY = 10

  Result = Struct.new(:notified_count, :providers_notified, keyword_init: true)

  def self.call(service_request)
    new(service_request).notify
  end

  def initialize(service_request)
    @sr = service_request
  end

  def notify
    location_hash = build_location_hash
    search_result = SearchProvidersService.call(category: @sr.category, location: location_hash)

    providers = search_result.providers.first(MAX_PROVIDERS_TO_NOTIFY)

    if providers.none?
      Rails.logger.info("[NotifyProvidersService] No providers found for SR##{@sr.id} (#{@sr.category})")
      return Result.new(notified_count: 0, providers_notified: [])
    end

    notified = []
    message = Proposal.notification_for_provider(@sr)

    providers.each do |profile|
      next unless profile.user.present?
      next if already_notified?(profile.user)

      # Create lead to track notification
      Lead.create!(
        service_request: @sr,
        provider_user: profile.user,
        delivered_at: Time.current
      )

      # Set up provider conversation state to expect a proposal
      state = ConversationState.for_channel_user(
        channel: detect_channel(profile.user),
        channel_user_id: profile.user.phone_e164,
        user: profile.user
      )
      state.advance_to!(:provider_awaiting_proposal, "service_request_id" => @sr.id)

      # Send notification
      send_notification(profile.user, message)
      notified << profile.user

    rescue => e
      Rails.logger.error("[NotifyProvidersService] Failed to notify #{profile.user&.phone_e164}: #{e.message}")
    end

    @sr.update!(notified_providers_at: Time.current) if @sr.respond_to?(:notified_providers_at)

    Rails.logger.info("[NotifyProvidersService] Notified #{notified.size} providers for SR##{@sr.id}")
    Result.new(notified_count: notified.size, providers_notified: notified)
  end

  private

  def build_location_hash
    loc = @sr.location
    return {} unless loc
    {
      admin_area_1: loc.admin_area_1,
      locality: loc.locality
    }.compact
  end

  def already_notified?(user)
    Lead.exists?(service_request: @sr, provider_user: user)
  end

  def detect_channel(user)
    user.phone_e164.start_with?("+tg") ? "telegram" : "whatsapp"
  end

  def send_notification(user, message)
    if user.phone_e164.start_with?("+tg")
      # Telegram: extract chat_id from synthetic phone
      chat_id = user.phone_e164.gsub("+tg", "")
      TelegramClient.send_message(chat_id: chat_id, text: message)
    else
      # WhatsApp: use WhatsApp client
      WhatsappClient.send_message(to: user.phone_e164, text: message)
    end
  end
end
