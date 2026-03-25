class Proposal < ApplicationRecord
  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }, prefix: true

  belongs_to :service_request
  belongs_to :provider_user, class_name: "User"

  validates :price_cents, presence: true, numericality: { greater_than: 0 }
  validates :available_date, presence: true
  validates :provider_user_id, uniqueness: { scope: :service_request_id, message: "ya envió una propuesta para esta solicitud" }

  after_create :update_service_request_status

  def accept!
    update!(status: :accepted)
  end

  def reject!
    update!(status: :rejected)
  end

  def price_display
    return "0" if price_cents.blank?
    number = price_cents / 100
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end

  # Formato del aviso que reciben los proveedores
  def self.notification_for_provider(service_request)
    lines = []
    lines << "📢 *Nueva solicitud cerca tuyo!*"
    lines << ""
    lines << "🔧 #{service_request.category.titleize}"
    lines << "📝 #{service_request.details.truncate(150)}"
    lines << "📍 #{service_request.location&.to_display || 'Sin ubicación'}"
    lines << ""
    lines << "¿Querés postularte?"
    lines << "Respondé con: *precio fecha*"
    lines << "Ej: `25000 viernes`"
    lines.join("\n")
  end

  private

  def update_service_request_status
    service_request.mark_with_proposals! if service_request.status_open?
  end
end
