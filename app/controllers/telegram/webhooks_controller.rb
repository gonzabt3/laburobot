module Telegram
  class WebhooksController < ApplicationController
    # Disable CSRF verification for webhook endpoint (Telegram sends POST requests)
    skip_before_action :verify_authenticity_token

    # POST /telegram/webhook
    # Receives Telegram updates and routes them through ConversationRouter.
    def create
      update = params.permit!.to_h

      # Validate the update has a message
      message = update.dig("message") || update.dig("edited_message")
      unless message
        render json: { ok: true }, status: :ok
        return
      end

      chat_id      = message.dig("chat", "id")
      text         = message["text"].to_s.strip
      sender_phone = extract_phone(message)

      # Skip non-text messages for MVP
      if text.blank?
        send_reply(chat_id, "Por ahora solo proceso mensajes de texto. ¡Escribíme algo!")
        render json: { ok: true }, status: :ok
        return
      end

      # Route through conversation router
      result = ConversationRouter.route(
        channel:      :telegram,
        sender_phone: sender_phone,
        text:         text,
        extras:       { chat_id: chat_id, raw_update: update }
      )

      send_reply(chat_id, result.reply) if result.reply.present?

      render json: { ok: true }, status: :ok
    rescue => e
      Rails.logger.error("[Telegram::WebhooksController] Error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      render json: { ok: true }, status: :ok
    end

    private

    # Extract a usable identifier for the sender.
    # Telegram doesn't expose phone by default, so we use chat_id prefixed with "+tg"
    def extract_phone(message)
      # If contact was shared, use the real phone
      contact = message["contact"]
      if contact&.dig("phone_number").present?
        phone = contact["phone_number"].to_s
        phone = "+#{phone}" unless phone.start_with?("+")
        return phone
      end

      # Use Telegram user ID as a synthetic phone-like identifier
      from_id = message.dig("from", "id")
      "+tg#{from_id}"
    end

    def send_reply(chat_id, text)
      TelegramClient.send_message(chat_id: chat_id, text: text)
    rescue => e
      Rails.logger.error("[Telegram::WebhooksController] Failed to send reply: #{e.message}")
    end
  end
end
