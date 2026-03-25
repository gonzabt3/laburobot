class AddStatusToServiceRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :service_requests, :status, :integer, default: 0, null: false
    add_column :service_requests, :expires_at, :datetime

    add_index :service_requests, :status
    add_index :service_requests, :expires_at
  end
end
