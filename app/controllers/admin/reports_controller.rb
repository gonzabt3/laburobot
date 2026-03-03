module Admin
  class ReportsController < BaseController
    layout "admin"

    def index
      @reports = Report.includes(:reporter_user, :target_user).order(created_at: :desc)
    end

    def update
      @report = Report.find(params[:id])
      @report.update!(status: params[:status])

      respond_to do |format|
        format.json { render json: { status: @report.status } }
        format.html { redirect_to admin_root_path, notice: "Report status updated." }
      end
    end
  end
end
