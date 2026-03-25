class CreateProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :proposals do |t|
      t.references :service_request, null: false, foreign_key: true
      t.references :provider_user, null: false, foreign_key: { to_table: :users }
      t.integer :price_cents, null: false
      t.string :available_date, null: false
      t.text :message
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :proposals, [:service_request_id, :provider_user_id], unique: true
    add_index :proposals, [:service_request_id, :status]
  end
end
