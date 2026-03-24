class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :phone_e164
      t.integer :role
      t.integer :status
      t.datetime :consent_at

      t.timestamps
    end
    add_index :users, :phone_e164, unique: true
  end
end
