module Admin
  class ProviderProfilesController < BaseController
    layout "admin"

    def index
      @provider_profiles = ProviderProfile.includes(:user, :location).order(created_at: :desc)
    end

    def toggle_active
      @profile = ProviderProfile.find(params[:id])
      @profile.update!(active: !@profile.active)

      respond_to do |format|
        format.json { render json: { active: @profile.active } }
        format.html { redirect_to admin_root_path, notice: "Provider #{@profile.active ? 'activated' : 'deactivated'}." }
      end
    end
  end
end
