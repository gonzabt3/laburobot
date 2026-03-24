# IntentExtractService: extracts structured fields from free-form text.
#
# Uses an LLM adapter if configured (via OPENAI_API_KEY or LLM_PROVIDER env vars).
# Falls back to a deterministic stub that works without any external keys.
#
# Usage:
#   result = IntentExtractService.call("Necesito un plomero urgente en Buenos Aires")
#   # => { intent: "demand", category_raw: "plomero", location_raw: "Buenos Aires",
#   #      urgency: "urgent", details: "...", missing_fields: [] }
class IntentExtractService
  DEMAND_KEYWORDS  = %w[necesito busco quiero requiero solicito].freeze
  OFFER_KEYWORDS   = %w[ofrezco soy oferto hago trabajo tengo].freeze
  URGENCY_MAP      = {
    "urgente"  => "urgent",
    "hoy"      => "today",
    "ahora"    => "today",
    "semana"   => "this_week",
    "flexible" => "flexible"
  }.freeze

  Result = Struct.new(:intent, :category_raw, :location_raw, :urgency, :details, :missing_fields, keyword_init: true)

  def self.call(text)
    new(text).extract
  end

  def initialize(text)
    @text = text.to_s.downcase.strip
  end

  def extract
    if llm_configured?
      extract_via_llm
    else
      extract_stub
    end
  end

  private

  def llm_configured?
    ENV["OPENAI_API_KEY"].present? || ENV["LLM_API_KEY"].present?
  end

  def extract_stub
    intent        = detect_intent
    category_raw  = detect_category
    location_raw  = detect_location
    urgency       = detect_urgency
    missing       = missing_fields(category_raw, location_raw)

    Result.new(
      intent:        intent,
      category_raw:  category_raw,
      location_raw:  location_raw,
      urgency:       urgency,
      details:       @text,
      missing_fields: missing
    )
  end

  def detect_intent
    return "offer"  if OFFER_KEYWORDS.any?  { |kw| @text.include?(kw) }
    return "demand" if DEMAND_KEYWORDS.any? { |kw| @text.include?(kw) }
    "demand" # default assumption
  end

  def detect_category
    all_keywords = ServiceCategories::CATALOG.flat_map { |cat, keywords| keywords.map { |kw| [ kw, cat ] } }.to_h
    all_keywords.each do |keyword, category|
      # Use word-boundary matching to avoid partial matches (e.g. "aire" in "buenos aires")
      return category if @text.match?(/\b#{Regexp.escape(keyword)}\b/)
    end
    nil
  end

  def detect_location
    # Simple heuristic: look for known Argentinian provinces/cities
    provinces = %w[buenos\ aires cordoba rosario mendoza tucuman salta misiones neuquen chubut]
    provinces.each { |p| return p if @text.include?(p) }

    # Look for "en <something>" pattern
    match = @text.match(/\ben\s+([a-záéíóúñ][a-záéíóúñ\s]{2,30})/i)
    match ? match[1].strip : nil
  end

  def detect_urgency
    URGENCY_MAP.each { |kw, val| return val if @text.include?(kw) }
    "flexible"
  end

  def missing_fields(category_raw, location_raw)
    missing = []
    missing << "category" if category_raw.blank?
    missing << "location" if location_raw.blank?
    missing
  end

  # LLM adapter – wire to a real provider via env vars:
  #   LLM_PROVIDER=openai  OPENAI_API_KEY=sk-...
  # The response must be a JSON object with the same keys as Result.
  def extract_via_llm
    require "httparty"
    provider = ENV.fetch("LLM_PROVIDER", "openai")

    prompt = build_prompt
    response = case provider
    when "openai"
      call_openai(prompt)
    else
      Rails.logger.warn("[IntentExtractService] Unknown LLM provider: #{provider}, falling back to stub")
      return extract_stub
    end

    parse_llm_response(response)
  rescue => e
    Rails.logger.error("[IntentExtractService] LLM call failed: #{e.message}, falling back to stub")
    extract_stub
  end

  def build_prompt
    <<~PROMPT
      Analyze this Spanish message from a local services marketplace in Argentina.
      Extract the following fields and respond in JSON only:
      - intent: "demand" (user needs a service) or "offer" (user provides a service)
      - category_raw: the service category mentioned (string or null)
      - location_raw: location mentioned (string or null)
      - urgency: one of "urgent", "today", "this_week", "flexible"
      - details: brief summary of what they need/offer
      - missing_fields: array of field names that are unclear or missing (e.g. ["category", "location"])

      Message: "#{@text}"

      Respond with valid JSON only, no explanation.
    PROMPT
  end

  def call_openai(prompt)
    api_key = ENV["OPENAI_API_KEY"] || ENV["LLM_API_KEY"]
    response = HTTParty.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type"  => "application/json"
      },
      body: {
        model: ENV.fetch("OPENAI_MODEL", "gpt-4o-mini"),
        messages: [ { role: "user", content: prompt } ],
        temperature: 0.1
      }.to_json
    )
    response.dig("choices", 0, "message", "content")
  end

  def parse_llm_response(content)
    data = JSON.parse(content.to_s.gsub(/```json|```/, "").strip)
    Result.new(
      intent:        data["intent"],
      category_raw:  data["category_raw"],
      location_raw:  data["location_raw"],
      urgency:       data["urgency"] || "flexible",
      details:       data["details"] || @text,
      missing_fields: Array(data["missing_fields"])
    )
  rescue JSON::ParserError => e
    Rails.logger.error("[IntentExtractService] Failed to parse LLM response: #{e.message}")
    extract_stub
  end
end
