# NotifyProvidersJob: async job to notify providers about a new service request.
#
# Enqueued right after a ServiceRequest is created.
class NotifyProvidersJob < ApplicationJob
  queue_as :default

  def perform(service_request_id)
    service_request = ServiceRequest.find_by(id: service_request_id)
    return unless service_request&.status_open?

    NotifyProvidersService.call(service_request)
  end
end
