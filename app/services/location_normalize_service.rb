# LocationNormalizeService: normalizes a raw location text or GPS coordinates
# for Argentina (country/province/city level).
#
# Usage:
#   LocationNormalizeService.normalize("Buenos Aires")
#   # => { country: "AR", admin_area_1: "Buenos Aires", locality: nil, raw_text: "Buenos Aires" }
#
#   LocationNormalizeService.normalize_gps(-34.6037, -58.3816)
#   # => { country: "AR", admin_area_1: "Buenos Aires", locality: "CABA", lat: ..., lng: ... }
class LocationNormalizeService
  PROVINCE_MAP = {
    "buenos aires"    => "Buenos Aires",
    "caba"            => "Buenos Aires",
    "capital federal" => "Buenos Aires",
    "cba"             => "Córdoba",
    "cordoba"         => "Córdoba",
    "córdoba"         => "Córdoba",
    "rosario"         => "Santa Fe",
    "santa fe"        => "Santa Fe",
    "mendoza"         => "Mendoza",
    "tucuman"         => "Tucumán",
    "tucumán"         => "Tucumán",
    "salta"           => "Salta",
    "misiones"        => "Misiones",
    "neuquen"         => "Neuquén",
    "neuquén"         => "Neuquén",
    "chubut"          => "Chubut",
    "entre rios"      => "Entre Ríos",
    "entre ríos"      => "Entre Ríos",
    "jujuy"           => "Jujuy",
    "chaco"           => "Chaco",
    "corrientes"      => "Corrientes",
    "santiago del estero" => "Santiago del Estero",
    "la rioja"        => "La Rioja",
    "catamarca"       => "Catamarca",
    "san luis"        => "San Luis",
    "san juan"        => "San Juan",
    "la pampa"        => "La Pampa",
    "rio negro"       => "Río Negro",
    "río negro"       => "Río Negro",
    "santa cruz"      => "Santa Cruz",
    "tierra del fuego" => "Tierra del Fuego",
    "formosa"         => "Formosa"
  }.freeze

  CITY_TO_PROVINCE = {
    "buenos aires"    => "Buenos Aires",
    "cordoba"         => "Córdoba",
    "rosario"         => "Santa Fe",
    "mendoza"         => "Mendoza",
    "la plata"        => "Buenos Aires",
    "mar del plata"   => "Buenos Aires",
    "tucuman"         => "Tucumán",
    "salta"           => "Salta"
  }.freeze

  Result = Struct.new(:country, :admin_area_1, :locality, :neighborhood, :lat, :lng, :raw_text, keyword_init: true)

  def self.normalize(raw_text)
    new.normalize(raw_text)
  end

  def self.normalize_gps(lat, lng, raw_text: nil)
    new.normalize_gps(lat, lng, raw_text: raw_text)
  end

  def normalize(raw_text)
    return Result.new(country: "AR", raw_text: raw_text.to_s) if raw_text.blank?

    text = raw_text.to_s.downcase.strip
    province  = detect_province(text)
    locality  = detect_locality(text, province)

    Result.new(
      country:     "AR",
      admin_area_1: province,
      locality:    locality,
      neighborhood: nil,
      lat:         nil,
      lng:         nil,
      raw_text:    raw_text.to_s
    )
  end

  def normalize_gps(lat, lng, raw_text: nil)
    # GPS normalization: for MVP, accept coordinates and optionally reverse-geocode
    # Reverse geocoding via a real API can be wired with GEOCODE_API_KEY env var.
    result = if ENV["GEOCODE_API_KEY"].present?
      reverse_geocode(lat, lng)
    else
      stub_gps_result(lat, lng)
    end

    result.lat     = lat.to_f
    result.lng     = lng.to_f
    result.raw_text = raw_text || "#{lat},#{lng}"
    result
  end

  private

  def detect_province(text)
    PROVINCE_MAP.each { |key, val| return val if text.include?(key) }
    nil
  end

  def detect_locality(text, province)
    CITY_TO_PROVINCE.each { |city, _| return city.titleize if text.include?(city) }
    nil
  end

  def stub_gps_result(lat, lng)
    # Rough bounding box check for Argentina (lat -22 to -55, lng -53 to -73)
    in_argentina = lat.to_f.between?(-55.0, -22.0) && lng.to_f.between?(-73.0, -53.0)
    Result.new(
      country:     in_argentina ? "AR" : nil,
      admin_area_1: nil,
      locality:    nil,
      neighborhood: nil,
      lat:         nil,
      lng:         nil,
      raw_text:    ""
    )
  end

  def reverse_geocode(lat, lng)
    require "httparty"
    response = HTTParty.get(
      "https://maps.googleapis.com/maps/api/geocode/json",
      query: {
        latlng: "#{lat},#{lng}",
        key:    ENV["GEOCODE_API_KEY"],
        language: "es",
        result_type: "administrative_area_level_1|locality"
      }
    )
    parse_geocode_response(response)
  rescue => e
    Rails.logger.error("[LocationNormalizeService] Geocode failed: #{e.message}")
    stub_gps_result(lat, lng)
  end

  def parse_geocode_response(response)
    results = response["results"]
    return stub_gps_result(nil, nil) if results.blank?

    components = results.first.dig("address_components") || []
    country   = find_component(components, "country")
    province  = find_component(components, "administrative_area_level_1")
    locality  = find_component(components, "locality") || find_component(components, "sublocality")

    Result.new(
      country:     country&.dig("short_name"),
      admin_area_1: province&.dig("long_name"),
      locality:    locality&.dig("long_name"),
      neighborhood: nil,
      lat:         nil,
      lng:         nil,
      raw_text:    ""
    )
  end

  def find_component(components, type)
    components.find { |c| c["types"].include?(type) }
  end
end
