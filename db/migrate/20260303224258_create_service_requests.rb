class CreateServiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :service_requests do |t|
      t.references :client_user, null: false, foreign_key: { to_table: :users }
      t.string :category
      t.references :location, null: true
      t.text :details
      t.integer :urgency
      t.datetime :needed_at

      t.timestamps
    end
  end
end
