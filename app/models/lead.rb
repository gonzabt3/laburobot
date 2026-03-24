class Lead < ApplicationRecord
  belongs_to :service_request
  belongs_to :provider_user, class_name: "User"
  has_one :rating, dependent: :destroy

  validates :service_request, presence: true
  validates :provider_user, presence: true
  validates :provider_user_id, uniqueness: { scope: :service_request_id }
end
