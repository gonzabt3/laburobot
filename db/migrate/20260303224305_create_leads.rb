class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :provider_user, null: false, foreign_key: { to_table: :users }
      t.datetime :delivered_at

      t.timestamps
    end
  end
end
