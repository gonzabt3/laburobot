module Telegram
  class WebhooksController < ApplicationController
    # CSRF verification is disabled for this webhook endpoint because Telegram sends
    # standard POST requests without CSRF tokens. Security is instead enforced by
    # validating the X-Telegram-Bot-Api-Secret-Token header (see verify_telegram_secret!).
    skip_before_action :verify_authenticity_token
    before_action :verify_telegram_secret!

    # POST /telegram/webhook
    # Receives Telegram updates and routes them through ConversationStateMachine.
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

      # Skip non-text messages for now
      if text.blank?
        send_reply(chat_id, "Por ahora solo proceso mensajes de texto. ¡Escribíme algo!")
        render json: { ok: true }, status: :ok
        return
      end

      # Route through stateful conversation machine
      result = ConversationStateMachine.process(
        channel:         :telegram,
        channel_user_id: sender_phone,
        sender_phone:    sender_phone,
        text:            text,
        extras:          { chat_id: chat_id, raw_update: update }
      )

      send_reply(chat_id, result.reply) if result.reply.present?

      render json: { ok: true }, status: :ok
    rescue => e
      Rails.logger.error("[Telegram::WebhooksController] Error: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      render json: { ok: true }, status: :ok
    end

    private

    # Validates the X-Telegram-Bot-Api-Secret-Token header.
    # Set TELEGRAM_WEBHOOK_SECRET to the same value you use when registering the webhook:
    #   TelegramClient.set_webhook(url: "...", secret_token: ENV["TELEGRAM_WEBHOOK_SECRET"])
    # When the env var is not set (e.g. in development), validation is skipped.
    def verify_telegram_secret!
      secret = ENV["TELEGRAM_WEBHOOK_SECRET"]
      return unless secret.present?

      provided = request.headers["X-Telegram-Bot-Api-Secret-Token"]
      unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, secret)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

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
