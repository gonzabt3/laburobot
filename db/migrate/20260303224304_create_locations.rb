class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.references :locatable, polymorphic: true, null: false
      t.string :country
      t.string :admin_area_1
      t.string :locality
      t.string :neighborhood
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :raw_text
      t.datetime :normalized_at

      t.timestamps
    end
  end
end
