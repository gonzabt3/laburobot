require "test_helper"

class IntentExtractServiceTest < ActiveSupport::TestCase
  test "detects demand intent from keyword" do
    result = IntentExtractService.call("Necesito un plomero en Buenos Aires")
    assert_equal "demand", result.intent
  end

  test "detects offer intent from keyword" do
    result = IntentExtractService.call("Ofrezco servicios de pintura en Córdoba")
    assert_equal "offer", result.intent
  end

  test "extracts category from text" do
    result = IntentExtractService.call("Busco un electricista urgente")
    assert_equal "electricidad", result.category_raw
  end

  test "extracts location from 'en <city>' pattern" do
    result = IntentExtractService.call("Necesito un pintor en Buenos Aires")
    assert_equal "buenos aires", result.location_raw
  end

  test "detects urgent urgency" do
    result = IntentExtractService.call("Necesito plomero urgente")
    assert_equal "urgent", result.urgency
  end

  test "returns missing_fields when category is absent" do
    result = IntentExtractService.call("Necesito ayuda en Buenos Aires")
    assert_includes result.missing_fields, "category"
  end

  test "returns missing_fields when location is absent" do
    result = IntentExtractService.call("Necesito un plomero")
    assert_includes result.missing_fields, "location"
  end

  test "returns details as original text" do
    text = "Busco electricista para arreglar un enchufe"
    result = IntentExtractService.call(text)
    assert_equal text.downcase.strip, result.details
  end
end
