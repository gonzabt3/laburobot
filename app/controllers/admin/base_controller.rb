module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      username = ENV.fetch("ADMIN_USERNAME", "admin")
      password = ENV.fetch("ADMIN_PASSWORD", "changeme")

      authenticate_or_request_with_http_basic("LaburoBot Admin") do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u, username) &
          ActiveSupport::SecurityUtils.secure_compare(p, password)
      end
    end
  end
end
