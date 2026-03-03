# WhatsApp Cloud API adapter placeholder.
#
# Required env vars:
#   WHATSAPP_TOKEN             - Meta Cloud API access token
#   WHATSAPP_PHONE_NUMBER_ID   - The phone number ID from Meta Business Manager
#   WHATSAPP_VERIFY_TOKEN      - Webhook verification token you choose
#   WHATSAPP_APP_SECRET        - App secret for signature validation (optional but recommended)
#
# Meta documentation: https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks
#
# TODO: Replace stub implementations with real API calls once Meta app is configured.

module Whatsapp
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    # GET /whatsapp/webhook
    # Meta webhook verification challenge
    def show
      mode      = params["hub.mode"]
      token     = params["hub.verify_token"]
      challenge = params["hub.challenge"]

      if mode == "subscribe" && token == ENV["WHATSAPP_VERIFY_TOKEN"]
        render plain: challenge, status: :ok
      else
        render json: { error: "Verification failed" }, status: :forbidden
      end
    end

    # POST /whatsapp/webhook
    # Receives WhatsApp Cloud API updates
    def create
      # TODO: validate X-Hub-Signature-256 header using WHATSAPP_APP_SECRET

      payload = params.permit!.to_h
      entries = payload.dig("entry") || []

      entries.each do |entry|
        changes = entry.dig("changes") || []
        changes.each do |change|
          value    = change.dig("value") || {}
          messages = value.dig("messages") || []

          messages.each { |msg| process_message(msg, value) }
        end
      end

      render json: { ok: true }, status: :ok
    rescue => e
      Rails.logger.error("[Whatsapp::WebhooksController] Error: #{e.class} - #{e.message}")
      render json: { ok: true }, status: :ok
    end

    private

    def process_message(message, value)
      msg_type = message["type"]
      return unless msg_type == "text"

      sender_phone = message["from"]
      text         = message.dig("text", "body").to_s.strip
      wa_message_id = message["id"]

      sender_phone = "+#{sender_phone}" unless sender_phone.start_with?("+")

      result = ConversationRouter.route(
        channel:      :whatsapp,
        sender_phone: sender_phone,
        text:         text,
        extras:       { wa_message_id: wa_message_id, raw_value: value }
      )

      send_reply(sender_phone, result.reply) if result.reply.present?
    end

    def send_reply(to_phone, text)
      WhatsappClient.send_text(to: to_phone, text: text)
    rescue => e
      Rails.logger.error("[Whatsapp::WebhooksController] Failed to send reply: #{e.message}")
    end
  end
end
