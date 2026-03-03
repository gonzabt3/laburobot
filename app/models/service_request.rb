class ServiceRequest < ApplicationRecord
  enum :urgency, { flexible: 0, this_week: 1, today: 2, urgent: 3 }, prefix: true

  belongs_to :client_user, class_name: "User"
  belongs_to :location, optional: true
  has_many :leads, dependent: :destroy

  validates :client_user, presence: true
  validates :category, presence: true
  validates :details, presence: true
end
