class Location < ApplicationRecord
  belongs_to :locatable, polymorphic: true

  validates :raw_text, presence: true

  def to_display
    parts = [ neighborhood, locality, admin_area_1, country ].compact.reject(&:blank?)
    parts.any? ? parts.join(", ") : raw_text
  end
end
