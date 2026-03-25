# NotifyProviderAcceptedJob: notifies a provider that their proposal was accepted.
#
# Sends connection info so the provider can contact the client directly.
class NotifyProviderAcceptedJob < ApplicationJob
  queue_as :default

  def perform(proposal_id)
    proposal = Proposal.find_by(id: proposal_id)
    return unless proposal&.status_accepted?

    sr = proposal.service_request
    provider = proposal.provider_user
    client = sr.client_user

    # Build contact link for provider → client
    url = ClickToChatService.whatsapp(
      phone: client.phone_e164,
      message: "Hola! Soy #{provider.display_name} de LaburoBot. " \
               "Aceptaste mi propuesta para #{sr.category}. ¿Coordinamos?"
    )

    message = "✅ *¡Te eligieron!*\n\n" \
              "📋 Solicitud: #{sr.category.titleize}\n" \
              "📝 #{sr.details.truncate(100)}\n\n" \
              "Contactá al cliente:\n📱 #{url}"

    send_to_provider(provider, message)
  end

  private

  def send_to_provider(provider, message)
    if provider.phone_e164.start_with?("+tg")
      chat_id = provider.phone_e164.gsub("+tg", "")
      TelegramClient.send_message(chat_id: chat_id, text: message)
    else
      WhatsappClient.send_message(to: provider.phone_e164, text: message)
    end
  rescue => e
    Rails.logger.error("[NotifyProviderAcceptedJob] Failed to notify provider #{provider.id}: #{e.message}")
  end
end
