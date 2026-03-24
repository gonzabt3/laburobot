# ConversationRouter: orchestrates the conversation flow for inbound messages.
#
# Receives a normalized message payload and routes it through the appropriate flow:
#   - New user onboarding
#   - Demand flow (client requesting a service)
#   - Offer flow (provider registering)
#   - Existing session continuation
#
# Usage:
#   result = ConversationRouter.route(
#     channel: :telegram,
#     sender_phone: "+5491112345678",
#     text: "Necesito un plomero en Buenos Aires"
#   )
#   # => { reply: "...", actions: [...] }
class ConversationRouter
  GREETING_KEYWORDS = %w[hola hi hello buenas saludos inicio start].freeze

  Result = Struct.new(:reply, :actions, :user, keyword_init: true)

  def self.route(channel:, sender_phone:, text:, extras: {})
    new(channel: channel, sender_phone: sender_phone, text: text, extras: extras).route
  end

  def initialize(channel:, sender_phone:, text:, extras: {})
    @channel      = channel
    @sender_phone = sender_phone.to_s
    @text         = text.to_s.strip
    @extras       = extras
  end

  def route
    @user = find_or_create_user

    return handle_greeting if greeting?
    return handle_demand    if demand?
    return handle_offer     if offer?

    handle_unknown
  end

  private

  def find_or_create_user
    User.find_or_create_by!(phone_e164: @sender_phone) do |u|
      u.role   = :client
      u.status = :active
    end
  end

  def greeting?
    GREETING_KEYWORDS.any? { |kw| @text.downcase.include?(kw) }
  end

  def demand?
    extracted.intent == "demand"
  end

  def offer?
    extracted.intent == "offer"
  end

  def extracted
    @extracted ||= IntentExtractService.call(@text)
  end

  def handle_greeting
    reply = <<~MSG.strip
      👋 ¡Hola! Soy LaburoBot.
      Puedo ayudarte a encontrar prestadores de servicios locales.

      ¿Qué necesitás?
      • Escribí lo que buscás, por ejemplo: "Necesito un plomero en Buenos Aires"
      • Si ofrecés un servicio, decíme: "Ofrezco pintura en Rosario"
    MSG
    Result.new(reply: reply, actions: [], user: @user)
  end

  def handle_demand
    category_raw = extracted.category_raw
    location_raw = extracted.location_raw

    if extracted.missing_fields.any?
      return ask_for_missing_fields(extracted.missing_fields)
    end

    category = CategoryNormalizeService.normalize(category_raw)
    location = LocationNormalizeService.normalize(location_raw)

    # Create service request
    service_request = create_service_request(category, location, extracted)

    # Find providers
    search_result = SearchProvidersService.call(
      category: category,
      location: { admin_area_1: location.admin_area_1, locality: location.locality }
    )

    if search_result.providers.none?
      reply = "Lo siento, no encontré prestadores de *#{category}* en tu zona por ahora. " \
              "Te avisaremos cuando haya alguien disponible."
      return Result.new(reply: reply, actions: [], user: @user)
    end

    # Enforce rate limit and deliver leads
    deliver_leads(service_request, search_result.providers)
  end

  def handle_offer
    # Register or update provider profile
    category_raw = extracted.category_raw
    location_raw = extracted.location_raw

    if extracted.missing_fields.any?
      return ask_for_missing_fields(extracted.missing_fields)
    end

    category = CategoryNormalizeService.normalize(category_raw)
    location = LocationNormalizeService.normalize(location_raw)

    @user.update!(role: :provider)
    profile = @user.provider_profile || @user.build_provider_profile
    profile.categories_list = (profile.categories_list + [ category ]).uniq
    profile.active           = true
    profile.service_area_type ||= :nationwide
    profile.save!

    reply = "✅ ¡Registrado! Aparecerás como prestador de *#{category}* en #{location.raw_text}. " \
            "Te contactaremos cuando alguien necesite tus servicios."
    Result.new(reply: reply, actions: [ :provider_registered ], user: @user)
  end

  def handle_unknown
    reply = "No entendí muy bien. Contame:\n" \
            "• ¿Necesitás un servicio? Por ejemplo: \"Busco electricista en Córdoba\"\n" \
            "• ¿Ofrecés un servicio? Por ejemplo: \"Ofrezco limpieza en Mendoza\""
    Result.new(reply: reply, actions: [], user: @user)
  end

  def ask_for_missing_fields(missing)
    questions = missing.map do |field|
      case field
      when "category" then "¿Qué tipo de servicio necesitás?"
      when "location" then "¿En qué ciudad o zona necesitás el servicio?"
      else "¿Podés darme más detalles sobre #{field}?"
      end
    end
    reply = "Para ayudarte necesito un poco más de información:\n" + questions.map { |q| "• #{q}" }.join("\n")
    Result.new(reply: reply, actions: [ :needs_more_info ], user: @user)
  end

  def create_service_request(category, location_result, extracted)
    # Create service request first (without location)
    sr = ServiceRequest.create!(
      client_user: @user,
      category:    category,
      details:     extracted.details,
      urgency:     extracted.urgency
    )

    # Now create location linked to the service request
    loc = Location.create!(
      locatable:    sr,
      country:      location_result.country,
      admin_area_1: location_result.admin_area_1,
      locality:     location_result.locality,
      raw_text:     location_result.raw_text,
      normalized_at: Time.current
    )

    sr.update!(location: loc)
    sr
  end

  def deliver_leads(service_request, providers)
    rate_check = RateLimitService.check(user: @user, service_request: service_request)

    unless rate_check.allowed?
      return Result.new(reply: rate_check.message, actions: [ :rate_limited ], user: @user)
    end

    links = providers.first(RateLimitService::MAX_LEADS_PER_REQUEST).filter_map do |profile|
      next unless profile.user.present?

      Lead.create!(service_request: service_request, provider_user: profile.user, delivered_at: Time.current)
      message = ClickToChatService.provider_intro_message(
        provider_profile: profile,
        service_request:  service_request
      )
      url = ClickToChatService.whatsapp(phone: profile.user.phone_e164, message: message)
      "• #{profile.user.phone_e164}: #{url}"
    end

    reply = "Encontré #{links.size} prestadores para tu pedido:\n\n#{links.join("\n")}\n\n" \
            "_Hacé click para contactarlos directamente._"
    Result.new(reply: reply, actions: [ :leads_delivered ], user: @user)
  end
end
