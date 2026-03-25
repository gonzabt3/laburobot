# ExpireRequestsJob: closes service requests that have expired without resolution.
#
# Should be run periodically (e.g. every hour via cron/Solid Queue recurring).
class ExpireRequestsJob < ApplicationJob
  queue_as :default

  def perform
    expired = ServiceRequest.expirable
    count = 0

    expired.find_each do |sr|
      sr.expire!
      sr.proposals.where(status: :pending).update_all(status: Proposal.statuses[:expired])

      # Notify client
      notify_client_expired(sr)
      count += 1
    end

    Rails.logger.info("[ExpireRequestsJob] Expired #{count} service requests")
  end

  private

  def notify_client_expired(sr)
    state = ConversationState.find_by(user: sr.client_user)
    chat_id = state&.fetch("chat_id")
    return unless chat_id.present?

    state.reset!

    message = "⏰ Tu solicitud ##{sr.id} (#{sr.category.titleize}) expiró sin propuestas.\n\n" \
              "Podés crear una nueva cuando quieras."

    client = sr.client_user
    if client.phone_e164.start_with?("+tg")
      TelegramClient.send_message(chat_id: chat_id, text: message)
    else
      WhatsappClient.send_message(to: client.phone_e164, text: message)
    end
  rescue => e
    Rails.logger.error("[ExpireRequestsJob] Failed to notify client for SR##{sr.id}: #{e.message}")
  end
end
