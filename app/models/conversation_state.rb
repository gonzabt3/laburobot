class ConversationState < ApplicationRecord
  EXPIRY_HOURS = 2

  enum :step, {
    idle: 0,
    awaiting_category: 1,
    awaiting_description: 2,
    awaiting_location: 3,
    awaiting_provider_selection: 4,
    awaiting_confirmation: 5,
    provider_awaiting_proposal: 10
  }, prefix: true

  belongs_to :user
  belongs_to :service_request, optional: true

  validates :channel, presence: true
  validates :channel_user_id, presence: true
  validates :channel_user_id, uniqueness: { scope: :channel }

  scope :active, -> { where.not(step: :idle) }
  scope :expired, -> { active.where("expires_at <= ?", Time.current) }

  def self.for_channel_user(channel:, channel_user_id:, user:)
    find_or_create_by!(channel: channel, channel_user_id: channel_user_id) do |cs|
      cs.user = user
      cs.step = :idle
      cs.data = {}
    end
  end

  def idle?
    step_idle?
  end

  def active?
    !idle?
  end

  def reset!
    update!(step: :idle, data: {}, service_request: nil, expires_at: nil)
  end

  def advance_to!(new_step, extra_data = {})
    update!(
      step: new_step,
      data: data.merge(extra_data),
      expires_at: EXPIRY_HOURS.hours.from_now
    )
  end

  # Helpers para guardar datos temporales del flujo
  def store(key, value)
    self.data = data.merge(key.to_s => value)
    save!
  end

  def fetch(key, default = nil)
    data.fetch(key.to_s, default)
  end
end
