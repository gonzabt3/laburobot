# CategoryNormalizeService: maps extracted category terms to catalog keys.
#
# Usage:
#   CategoryNormalizeService.normalize("plomero")   # => "plomeria"
#   CategoryNormalizeService.normalize("electricidad") # => "electricidad"
#   CategoryNormalizeService.normalize("xyz")       # => "otro"
class CategoryNormalizeService
  def self.normalize(raw_term)
    return "otro" if raw_term.blank?

    term = raw_term.to_s.downcase.strip

    # Direct key match
    return term if ServiceCategories::CATALOG.key?(term)

    # Keyword-to-category match
    ServiceCategories::CATALOG.each do |category, keywords|
      return category if keywords.any? { |kw| term.include?(kw) || kw.include?(term) }
    end

    # Fuzzy/partial key match
    ServiceCategories::ALL_KEYS.each do |key|
      return key if key.include?(term) || term.include?(key)
    end

    "otro"
  end
end
