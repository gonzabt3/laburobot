class CreateProviderProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.text :categories
      t.text :description
      t.boolean :active
      t.integer :service_area_type
      t.integer :max_distance_km

      t.timestamps
    end
  end
end
