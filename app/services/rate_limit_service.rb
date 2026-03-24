# RateLimitService: enforces contact delivery caps to prevent abuse.
#
# Caps:
#   - Max 3 providers delivered per service request
#   - Max 10 providers delivered per client per day
#   - Cooldown: 30 seconds between consecutive requests
#
# Usage:
#   check = RateLimitService.check(user: current_user, service_request: request)
#   if check.allowed?
#     # deliver lead
#   else
#     # show check.message to user
#   end
class RateLimitService
  MAX_LEADS_PER_REQUEST = 3
  MAX_LEADS_PER_DAY     = 10
  COOLDOWN_SECONDS      = 30

  Result = Struct.new(:allowed, :message, :wait_seconds, keyword_init: true) do
    def allowed? = allowed
  end

  def self.check(user:, service_request:)
    new(user: user, service_request: service_request).check
  end

  def initialize(user:, service_request:)
    @user            = user
    @service_request = service_request
  end

  def check
    result = check_cooldown
    return result unless result.allowed?

    result = check_request_cap
    return result unless result.allowed?

    check_daily_cap
  end

  private

  def check_cooldown
    last_lead = Lead.where(service_request: @service_request)
                    .order(created_at: :desc)
                    .first

    if last_lead.present?
      elapsed = Time.current - last_lead.created_at
      if elapsed < COOLDOWN_SECONDS
        wait = (COOLDOWN_SECONDS - elapsed).ceil
        return Result.new(
          allowed: false,
          message: "Por favor esperá #{wait} segundos antes de solicitar otro contacto.",
          wait_seconds: wait
        )
      end
    end

    Result.new(allowed: true, message: nil, wait_seconds: 0)
  end

  def check_request_cap
    count = Lead.where(service_request: @service_request).count
    if count >= MAX_LEADS_PER_REQUEST
      Result.new(
        allowed: false,
        message: "Ya recibiste el máximo de #{MAX_LEADS_PER_REQUEST} contactos para esta solicitud.",
        wait_seconds: 0
      )
    else
      Result.new(allowed: true, message: nil, wait_seconds: 0)
    end
  end

  def check_daily_cap
    count = Lead.joins(:service_request)
                .where(service_requests: { client_user_id: @user.id })
                .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
                .count

    if count >= MAX_LEADS_PER_DAY
      Result.new(
        allowed: false,
        message: "Alcanzaste el límite diario de #{MAX_LEADS_PER_DAY} contactos. Intentá de nuevo mañana.",
        wait_seconds: 0
      )
    else
      Result.new(allowed: true, message: nil, wait_seconds: 0)
    end
  end
end
