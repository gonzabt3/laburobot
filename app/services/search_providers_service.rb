# SearchProvidersService: finds provider profiles matching a service request.
#
# Usage:
#   providers = SearchProvidersService.call(
#     category: "plomeria",
#     location: { admin_area_1: "Buenos Aires", locality: "Palermo" }
#   )
class SearchProvidersService
  MAX_RESULTS = 10

  Result = Struct.new(:providers, :matched_by, keyword_init: true)

  def self.call(category:, location: {})
    new(category: category, location: location).search
  end

  def initialize(category:, location: {})
    @category = category.to_s
    @location = location.is_a?(Hash) ? location : {}
  end

  def search
    scope = ProviderProfile.includes(:user, :location).where(active: true)

    # Filter by category
    category_scope = scope.where("categories LIKE ?", "%#{@category}%")

    # Apply location filter
    results = apply_location_filter(category_scope)

    # Fallback: if no results, return all active providers in that category
    if results.empty?
      results = category_scope.limit(MAX_RESULTS)
      matched_by = "category_only"
    else
      matched_by = "category_and_location"
    end

    # Second fallback: if still empty, return any active providers (different category)
    if results.empty?
      results = scope.limit(MAX_RESULTS)
      matched_by = "any_active"
    end

    Result.new(providers: results.limit(MAX_RESULTS), matched_by: matched_by)
  end

  private

  def apply_location_filter(scope)
    province = @location[:admin_area_1] || @location["admin_area_1"]
    locality  = @location[:locality] || @location["locality"]

    return scope if province.blank? && locality.blank?

    # Collect matching IDs from multiple strategies
    nationwide_ids = scope.where(service_area_type: ProviderProfile.service_area_types[:nationwide]).pluck(:id)

    provincial_ids = if province.present?
      scope.joins(:location).where(locations: { admin_area_1: province }).pluck(:id)
    else
      []
    end

    city_ids = if locality.present?
      scope.joins(:location).where(locations: { locality: locality }).pluck(:id)
    else
      []
    end

    all_ids = (nationwide_ids + provincial_ids + city_ids).uniq
    all_ids.any? ? scope.where(id: all_ids) : scope.none
  end
end
