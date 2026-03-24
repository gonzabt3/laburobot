class User < ApplicationRecord
  # Accepts:
  #   E.164 phone numbers: +5491112345678
  #   Telegram synthetic IDs: +tg123456789
  PHONE_E164_REGEX = /\A(\+[1-9]\d{6,14}|\+tg\d{1,15})\z/

  enum :role, { client: 0, provider: 1 }, prefix: true
  enum :status, { active: 0, suspended: 1, blocked: 2 }, prefix: true

  has_one :provider_profile, dependent: :destroy
  has_many :service_requests, foreign_key: :client_user_id, dependent: :destroy
  has_many :leads, foreign_key: :provider_user_id, dependent: :destroy
  has_many :reports_filed, class_name: "Report", foreign_key: :reporter_user_id, dependent: :destroy
  has_many :reports_received, class_name: "Report", foreign_key: :target_user_id, dependent: :destroy

  validates :phone_e164, presence: true, uniqueness: true, format: { with: PHONE_E164_REGEX }
  validates :role, presence: true
  validates :status, presence: true

  before_validation :set_defaults

  private

  def set_defaults
    self.status ||= :active
  end
end
