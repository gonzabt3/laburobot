# ClickToChatService: builds wa.me and Telegram click-to-chat URLs.
#
# Usage:
#   ClickToChatService.whatsapp(phone: "+5491112345678", message: "Hola, vi tu perfil en LaburoBot")
#   # => "https://wa.me/5491112345678?text=Hola%2C+vi+tu+perfil+en+LaburoBot"
#
#   ClickToChatService.telegram(username: "johndoe", message: "Hola")
#   # => "https://t.me/johndoe?start=Hola"
class ClickToChatService
  WHATSAPP_BASE = "https://wa.me/"
  TELEGRAM_BASE = "https://t.me/"

  def self.whatsapp(phone:, message: nil)
    # Strip leading + from phone number for wa.me format
    number = phone.to_s.gsub(/\A\+/, "")
    url    = "#{WHATSAPP_BASE}#{number}"
    url   += "?text=#{URI.encode_www_form_component(message)}" if message.present?
    url
  end

  def self.telegram(username: nil, phone: nil, message: nil)
    if username.present?
      url = "#{TELEGRAM_BASE}#{username}"
      url += "?start=#{URI.encode_www_form_component(message)}" if message.present?
      url
    elsif phone.present?
      number = phone.to_s.gsub(/\A\+/, "")
      "#{WHATSAPP_BASE}#{number}"
    else
      raise ArgumentError, "username or phone is required"
    end
  end

  # Builds a prefilled message for a provider introduction
  def self.provider_intro_message(provider_profile:, service_request:)
    user   = provider_profile.user
    cats   = provider_profile.categories_list.first(3).join(", ")

    "Hola! Te contacto desde LaburoBot. " \
    "Ofrezco servicios de #{cats}. " \
    "Vi que necesitás: #{service_request.details.truncate(120)}. " \
    "¿Podemos hablar?"
  end
end
