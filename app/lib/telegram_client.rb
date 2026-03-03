# TelegramClient: thin wrapper around Telegram Bot API
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN - your bot token from @BotFather
#
# Usage:
#   TelegramClient.send_message(chat_id: 12345, text: "Hello!")
#   TelegramClient.set_webhook(url: "https://yourdomain.com/telegram/webhook")
class TelegramClient
  include HTTParty
  base_uri "https://api.telegram.org"

  def self.bot_token
    ENV.fetch("TELEGRAM_BOT_TOKEN") { raise "TELEGRAM_BOT_TOKEN env var not set" }
  end

  def self.api_url(method)
    "/bot#{bot_token}/#{method}"
  end

  def self.send_message(chat_id:, text:, parse_mode: "Markdown", **opts)
    post(api_url("sendMessage"), body: {
      chat_id:    chat_id,
      text:       text,
      parse_mode: parse_mode
    }.merge(opts).to_json, headers: { "Content-Type" => "application/json" })
  end

  def self.set_webhook(url:, secret_token: nil)
    body = { url: url }
    body[:secret_token] = secret_token if secret_token.present?
    post(api_url("setWebhook"), body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def self.delete_webhook
    post(api_url("deleteWebhook"))
  end

  def self.get_me
    get(api_url("getMe"))
  end
end
