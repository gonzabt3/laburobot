# WhatsappClient: stub client for WhatsApp Cloud API outbound messaging.
#
# Required env vars:
#   WHATSAPP_TOKEN           - Bearer token from Meta
#   WHATSAPP_PHONE_NUMBER_ID - Phone number ID from Meta Business Manager
#
# TODO: Implement send_text and other methods once Meta app is provisioned.
class WhatsappClient
  include HTTParty

  API_VERSION = "v19.0"

  def self.base_url
    "https://graph.facebook.com/#{API_VERSION}/#{phone_number_id}"
  end

  def self.phone_number_id
    ENV.fetch("WHATSAPP_PHONE_NUMBER_ID", "PLACEHOLDER_PHONE_NUMBER_ID")
  end

  def self.token
    ENV.fetch("WHATSAPP_TOKEN", "")
  end

  # Send a plain text message via WhatsApp Cloud API
  #
  # TODO: implement real HTTP call once Meta app is configured
  def self.send_text(to:, text:)
    raise NotImplementedError, "WhatsApp adapter not yet implemented. " \
      "Set WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID and implement this method." \
      " See: https://developers.facebook.com/docs/whatsapp/cloud-api/messages/text-messages"

    # When ready, uncomment and use:
    # post(
    #   "#{base_url}/messages",
    #   headers: {
    #     "Authorization" => "Bearer #{token}",
    #     "Content-Type"  => "application/json"
    #   },
    #   body: {
    #     messaging_product: "whatsapp",
    #     to:                to.gsub(/\A\+/, ""),
    #     type:              "text",
    #     text:              { body: text }
    #   }.to_json
    # )
  end
end
