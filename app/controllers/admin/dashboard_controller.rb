module Admin
  class DashboardController < BaseController
    layout "admin"

    def index
      @stats = {
        total_users:            User.count,
        total_providers:        User.role_provider.count,
        total_clients:          User.role_client.count,
        total_service_requests: ServiceRequest.count,
        total_leads:            Lead.count,
        leads_today:            Lead.where(created_at: Time.current.beginning_of_day..).count,
        open_reports:           Report.status_pending.count
      }
      @provider_profiles = ProviderProfile.includes(:user).order(created_at: :desc)
      @reports            = Report.includes(:reporter_user, :target_user).order(created_at: :desc)

      render :index
    end
  end
end
