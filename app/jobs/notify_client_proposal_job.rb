# NotifyClientProposalJob: notifies the client when a provider submits a proposal.
#
# Sends a Telegram/WhatsApp message to the client with the updated proposals list.
class NotifyClientProposalJob < ApplicationJob
  queue_as :default

  def perform(proposal_id)
    proposal = Proposal.find_by(id: proposal_id)
    return unless proposal&.status_pending?

    sr = proposal.service_request
    return unless sr.status_open? || sr.status_with_proposals?

    client = sr.client_user
    state = ConversationState.find_by(user: client)
    return unless state

    chat_id = state.fetch("chat_id")
    return unless chat_id.present?

    # Update client's conversation state to awaiting selection
    state.update!(
      step: :awaiting_provider_selection,
      service_request: sr,
      expires_at: ConversationState::EXPIRY_HOURS.hours.from_now
    )

    message = sr.formatted_proposals_for_client
    send_to_client(client, chat_id, message)
  end

  private

  def send_to_client(client, chat_id, message)
    if client.phone_e164.start_with?("+tg")
      TelegramClient.send_message(chat_id: chat_id, text: message)
    else
      WhatsappClient.send_message(to: client.phone_e164, text: message)
    end
  rescue => e
    Rails.logger.error("[NotifyClientProposalJob] Failed to notify client #{client.id}: #{e.message}")
  end
end
