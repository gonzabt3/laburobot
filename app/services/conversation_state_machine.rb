# ConversationStateMachine: routes messages based on conversation state.
#
# This replaces the stateless ConversationRouter with a stateful flow:
#   idle → awaiting_category → awaiting_description → awaiting_location → (create request)
#   provider_awaiting_proposal → (create proposal)
#   awaiting_provider_selection → awaiting_confirmation → (connect)
#
# Usage:
#   result = ConversationStateMachine.process(
#     channel: :telegram,
#     channel_user_id: "tg123456",
#     sender_phone: "+tg123456",
#     text: "necesito un plomero",
#     extras: { chat_id: 123456 }
#   )
class ConversationStateMachine
  GREETING_KEYWORDS = %w[hola hi hello buenas saludos inicio start /start].freeze
  CANCEL_KEYWORDS   = %w[cancelar cancel salir].freeze

  Result = Struct.new(:reply, :actions, :user, keyword_init: true)

  def self.process(channel:, channel_user_id:, sender_phone:, text:, extras: {})
    new(
      channel: channel,
      channel_user_id: channel_user_id,
      sender_phone: sender_phone,
      text: text,
      extras: extras
    ).process
  end

  def initialize(channel:, channel_user_id:, sender_phone:, text:, extras: {})
    @channel         = channel.to_s
    @channel_user_id = channel_user_id.to_s
    @sender_phone    = sender_phone.to_s
    @text            = text.to_s.strip
    @extras          = extras
  end

  def process
    @user  = find_or_create_user
    @state = ConversationState.for_channel_user(
      channel: @channel,
      channel_user_id: @channel_user_id,
      user: @user
    )

    # Check for cancellation
    return handle_cancel if cancel?

    # Check if state expired
    if @state.active? && @state.expires_at.present? && @state.expires_at <= Time.current
      @state.reset!
    end

    # Route based on current step
    case @state.step
    when "idle"
      handle_idle
    when "awaiting_category"
      handle_awaiting_category
    when "awaiting_description"
      handle_awaiting_description
    when "awaiting_location"
      handle_awaiting_location
    when "awaiting_provider_selection"
      handle_awaiting_provider_selection
    when "awaiting_confirmation"
      handle_awaiting_confirmation
    when "provider_awaiting_proposal"
      handle_provider_awaiting_proposal
    else
      @state.reset!
      handle_idle
    end
  end

  private

  # ── Step handlers ──────────────────────────────────────────────

  def handle_idle
    return handle_greeting if greeting?

    # Try to detect intent from the first message
    category = detect_category
    if category
      @state.advance_to!(:awaiting_description, "category" => category, "chat_id" => chat_id)
      return Result.new(
        reply: "👍 Entendido, necesitás un servicio de *#{category.titleize}*.\n\n¿Podés describir brevemente el problema?",
        actions: [:category_detected],
        user: @user
      )
    end

    # Check if this is a provider responding to a notification
    if @user.role_provider? && pending_provider_request.present?
      return handle_provider_awaiting_proposal
    end

    # Unknown — show help
    Result.new(
      reply: "¿En qué puedo ayudarte?\n\n" \
             "• Decime qué servicio necesitás, por ejemplo: \"necesito un plomero\"\n" \
             "• Escribí \"cancelar\" en cualquier momento para empezar de nuevo",
      actions: [],
      user: @user
    )
  end

  def handle_greeting
    @state.reset! if @state.active?
    Result.new(
      reply: "👋 ¡Hola! Soy *LaburoBot*.\n\n" \
             "Puedo ayudarte a encontrar prestadores de servicios locales.\n\n" \
             "¿Qué necesitás? Por ejemplo:\n" \
             "• \"Necesito un plomero\"\n" \
             "• \"Busco electricista\"\n" \
             "• \"Necesito pintor\"",
      actions: [:greeting],
      user: @user
    )
  end

  def handle_awaiting_category
    category = detect_category
    unless category
      return Result.new(
        reply: "No reconocí el servicio. Probá con alguno de estos:\n\n" \
               "🔧 Plomería, Electricidad, Albañilería\n" \
               "🎨 Pintura, Jardinería, Carpintería\n" \
               "🏠 Limpieza, Mudanza, Cerrajería\n\n" \
               "Escribí el que necesitás:",
        actions: [],
        user: @user
      )
    end

    @state.advance_to!(:awaiting_description, "category" => category, "chat_id" => chat_id)
    Result.new(
      reply: "👍 *#{category.titleize}*, perfecto.\n\n¿Podés describir brevemente el problema?",
      actions: [:category_detected],
      user: @user
    )
  end

  def handle_awaiting_description
    if @text.length < 5
      return Result.new(
        reply: "Necesito un poco más de detalle. ¿Qué problema tenés exactamente?",
        actions: [],
        user: @user
      )
    end

    @state.advance_to!(:awaiting_location, "description" => @text)
    Result.new(
      reply: "📝 Anotado.\n\n📍 ¿En qué zona o ciudad necesitás el servicio?",
      actions: [:description_saved],
      user: @user
    )
  end

  def handle_awaiting_location
    location_raw = @text

    if location_raw.length < 3
      return Result.new(
        reply: "¿Podés decirme la ciudad o barrio? Por ejemplo: \"Palermo, Buenos Aires\"",
        actions: [],
        user: @user
      )
    end

    # Normalize location
    location = LocationNormalizeService.normalize(location_raw)

    # Create the service request
    category    = @state.fetch("category")
    description = @state.fetch("description")

    service_request = ServiceRequest.create!(
      client_user: @user,
      category: category,
      details: description,
      status: :open
    )

    # Create location linked to service request
    loc = Location.create!(
      locatable: service_request,
      country: location.country,
      admin_area_1: location.admin_area_1,
      locality: location.locality,
      raw_text: location.raw_text,
      normalized_at: Time.current
    )
    service_request.update!(location: loc)

    # Store chat_id for later notifications
    @state.update!(
      step: :idle,
      service_request: service_request,
      data: @state.data.merge("chat_id" => chat_id)
    )

    # Notify providers asynchronously
    NotifyProvidersJob.perform_later(service_request.id)

    Result.new(
      reply: "✅ ¡Solicitud creada!\n\n" \
             "#{service_request.formatted_summary}\n\n" \
             "Estoy buscando prestadores en tu zona. " \
             "Te aviso cuando lleguen propuestas (hasta 24hs).",
      actions: [:service_request_created],
      user: @user
    )
  end

  def handle_awaiting_provider_selection
    sr = @state.service_request
    unless sr
      @state.reset!
      return handle_idle
    end

    # Parse selection: "1", "1,3", "1 3", "1 y 3"
    selections = @text.scan(/\d+/).map(&:to_i)
    pending = sr.pending_proposals.includes(provider_user: :provider_profile).to_a

    if selections.empty? || selections.any? { |s| s < 1 || s > pending.size }
      return Result.new(
        reply: "No entendí tu selección. Respondé con el número del prestador.\nEj: `1` o `1,2`",
        actions: [],
        user: @user
      )
    end

    chosen = selections.map { |i| pending[i - 1] }.compact.uniq

    # Accept chosen proposals, reject the rest
    chosen.each(&:accept!)
    (pending - chosen).each(&:reject!)
    sr.assign!

    # Build connection message for client
    lines = [ "✅ ¡Listo! Acá tenés los contactos:\n" ]
    chosen.each do |prop|
      provider = prop.provider_user
      url = ClickToChatService.whatsapp(
        phone: provider.phone_e164,
        message: ClickToChatService.provider_intro_message(
          provider_profile: provider.provider_profile,
          service_request: sr
        )
      )
      lines << "📱 #{provider.display_name}: #{url}"
    end
    lines << "\nDespués contanos cómo te fue ⭐"

    @state.reset!

    # Notify accepted providers
    chosen.each do |prop|
      NotifyProviderAcceptedJob.perform_later(prop.id)
    end

    Result.new(
      reply: lines.join("\n"),
      actions: [:providers_selected],
      user: @user
    )
  end

  def handle_awaiting_confirmation
    # Reserved for future use (double-confirm before connecting)
    handle_awaiting_provider_selection
  end

  def handle_provider_awaiting_proposal
    # Provider is responding with "precio fecha"
    sr = pending_provider_request

    unless sr
      @state.reset! if @state.active?
      return Result.new(
        reply: "No tenés solicitudes pendientes en este momento.",
        actions: [],
        user: @user
      )
    end

    # Parse: "25000 viernes" or "25000 mañana"
    match = @text.match(/(\d+)\s+(.+)/i)
    unless match
      return Result.new(
        reply: "Para postularte, respondé con precio y fecha disponible.\nEj: `25000 viernes`",
        actions: [],
        user: @user
      )
    end

    price_cents = match[1].to_i * 100
    available_date = match[2].strip

    if price_cents <= 0
      return Result.new(
        reply: "El precio debe ser mayor a 0. Ej: `25000 viernes`",
        actions: [],
        user: @user
      )
    end

    proposal = Proposal.create!(
      service_request: sr,
      provider_user: @user,
      price_cents: price_cents,
      available_date: available_date,
      status: :pending
    )

    @state.reset!

    # Notify client about new proposal
    NotifyClientProposalJob.perform_later(proposal.id)

    Result.new(
      reply: "✅ ¡Propuesta enviada!\n\n" \
             "💰 $#{proposal.price_display} - 📅 #{available_date}\n\n" \
             "Te aviso si el cliente te elige.",
      actions: [:proposal_created],
      user: @user
    )
  end

  def handle_cancel
    @state.reset!
    Result.new(
      reply: "🚫 Cancelado. ¿En qué puedo ayudarte?",
      actions: [:cancelled],
      user: @user
    )
  end

  # ── Helpers ───────────────────────────────────────────────────

  def find_or_create_user
    User.find_or_create_by!(phone_e164: @sender_phone) do |u|
      u.role   = :client
      u.status = :active
    end
  end

  def greeting?
    GREETING_KEYWORDS.any? { |kw| @text.downcase.include?(kw) }
  end

  def cancel?
    CANCEL_KEYWORDS.any? { |kw| @text.downcase.strip == kw }
  end

  def detect_category
    all_keywords = ServiceCategories::CATALOG.flat_map { |cat, keywords| keywords.map { |kw| [kw, cat] } }.to_h
    all_keywords.each do |keyword, category|
      return category if @text.downcase.match?(/\b#{Regexp.escape(keyword)}\b/)
    end
    nil
  end

  def chat_id
    @extras[:chat_id]&.to_s || @state.fetch("chat_id")
  end

  # Find a service request that this provider was notified about and hasn't responded to
  def pending_provider_request
    return nil unless @user.role_provider?

    @pending_provider_request ||= ServiceRequest
      .joins(:leads)
      .where(leads: { provider_user_id: @user.id })
      .where(status: [:open, :with_proposals])
      .where.not(id: Proposal.where(provider_user_id: @user.id).select(:service_request_id))
      .order(created_at: :desc)
      .first
  end
end
