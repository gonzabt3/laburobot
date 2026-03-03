class ProviderProfile < ApplicationRecord
  CATEGORY_SEPARATOR = ","

  enum :service_area_type, { nationwide: 0, province: 1, city: 2, neighborhood: 3 }, prefix: true

  belongs_to :user
  has_one :location, as: :locatable, dependent: :destroy

  validates :user, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :service_area_type, presence: true

  before_validation :set_defaults

  def categories_list
    return [] if categories.blank?
    categories.split(CATEGORY_SEPARATOR).map(&:strip)
  end

  def categories_list=(arr)
    self.categories = Array(arr).join(CATEGORY_SEPARATOR)
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.service_area_type ||= :nationwide
  end
end
