class ServiceRequest < ApplicationRecord
  PROPOSAL_EXPIRY_HOURS = 24

  enum :urgency, { flexible: 0, this_week: 1, today: 2, urgent: 3 }, prefix: true
  enum :status, {
    open: 0,
    with_proposals: 1,
    assigned: 2,
    completed: 3,
    expired: 4,
    cancelled: 5
  }, prefix: true

  belongs_to :client_user, class_name: "User"
  belongs_to :location, optional: true
  has_many :leads, dependent: :destroy
  has_many :proposals, dependent: :destroy

  validates :client_user, presence: true
  validates :category, presence: true
  validates :details, presence: true

  scope :open_requests,    -> { where(status: :open) }
  scope :with_proposals,   -> { where(status: :with_proposals) }
  scope :expirable,        -> { where(status: [:open, :with_proposals]).where("expires_at <= ?", Time.current) }

  before_create :set_expiry

  def expire!
    update!(status: :expired) if status_open? || status_with_proposals?
  end

  def mark_with_proposals!
    update!(status: :with_proposals) if status_open?
  end

  def assign!
    update!(status: :assigned)
  end

  def complete!
    update!(status: :completed) if status_assigned?
  end

  def accepted_proposals
    proposals.where(status: :accepted)
  end

  def pending_proposals
    proposals.where(status: :pending)
  end

  def formatted_summary
    lines = []
    lines << "📋 Solicitud ##{id}"
    lines << "🔧 #{category.titleize}"
    lines << "📝 #{details.truncate(100)}"
    lines << "📍 #{location&.to_display || 'Sin ubicación'}"
    lines.join("\n")
  end

  def formatted_proposals_for_client
    pending = pending_proposals.includes(provider_user: :provider_profile)
    return "Todavía no hay propuestas." if pending.none?

    lines = [ "🎉 ¡Tenés #{pending.count} propuesta#{'s' if pending.count > 1}!\n" ]
    pending.each_with_index do |prop, i|
      provider = prop.provider_user
      profile = provider.provider_profile
      rating_avg = provider.average_rating
      jobs_count = provider.completed_leads_count

      lines << "#{i + 1}️⃣ #{provider.display_name} ⭐#{rating_avg} (#{jobs_count} trabajos)"
      lines << "   💰 $#{prop.price_display} - 📅 #{prop.available_date}"
      lines << ""
    end
    lines << "Elegí con quién querés que te conectemos."
    lines << "Respondé con el número. Ej: 1"
    lines << "Podés elegir varios separados por coma. Ej: 1,3"
    lines.join("\n")
  end

  private

  def set_expiry
    self.expires_at ||= PROPOSAL_EXPIRY_HOURS.hours.from_now
  end
end
