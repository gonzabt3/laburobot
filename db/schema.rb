# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_24_235322) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversation_states", force: :cascade do |t|
    t.string "channel", null: false
    t.string "channel_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.datetime "expires_at"
    t.bigint "service_request_id"
    t.integer "step", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["channel", "channel_user_id"], name: "index_conversation_states_on_channel_and_channel_user_id", unique: true
    t.index ["service_request_id"], name: "index_conversation_states_on_service_request_id"
    t.index ["step"], name: "index_conversation_states_on_step"
    t.index ["user_id"], name: "index_conversation_states_on_user_id"
  end

  create_table "leads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.bigint "provider_user_id", null: false
    t.bigint "service_request_id", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_user_id"], name: "index_leads_on_provider_user_id"
    t.index ["service_request_id"], name: "index_leads_on_service_request_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "admin_area_1"
    t.string "country"
    t.datetime "created_at", null: false
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.string "locality"
    t.bigint "locatable_id", null: false
    t.string "locatable_type", null: false
    t.string "neighborhood"
    t.datetime "normalized_at"
    t.string "raw_text"
    t.datetime "updated_at", null: false
    t.index ["locatable_type", "locatable_id"], name: "index_locations_on_locatable"
  end

  create_table "proposals", force: :cascade do |t|
    t.string "available_date", null: false
    t.datetime "created_at", null: false
    t.text "message"
    t.integer "price_cents", null: false
    t.bigint "provider_user_id", null: false
    t.bigint "service_request_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["provider_user_id"], name: "index_proposals_on_provider_user_id"
    t.index ["service_request_id", "provider_user_id"], name: "index_proposals_on_service_request_id_and_provider_user_id", unique: true
    t.index ["service_request_id", "status"], name: "index_proposals_on_service_request_id_and_status"
    t.index ["service_request_id"], name: "index_proposals_on_service_request_id"
  end

  create_table "provider_profiles", force: :cascade do |t|
    t.boolean "active"
    t.text "categories"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "max_distance_km"
    t.integer "service_area_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_provider_profiles_on_user_id"
  end

  create_table "ratings", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "lead_id", null: false
    t.integer "score"
    t.datetime "updated_at", null: false
    t.index ["lead_id"], name: "index_ratings_on_lead_id"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "reason"
    t.bigint "reporter_user_id", null: false
    t.integer "status"
    t.bigint "target_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["reporter_user_id"], name: "index_reports_on_reporter_user_id"
    t.index ["target_user_id"], name: "index_reports_on_target_user_id"
  end

  create_table "service_requests", force: :cascade do |t|
    t.string "category"
    t.bigint "client_user_id", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.datetime "expires_at"
    t.bigint "location_id"
    t.datetime "needed_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "urgency"
    t.index ["client_user_id"], name: "index_service_requests_on_client_user_id"
    t.index ["expires_at"], name: "index_service_requests_on_expires_at"
    t.index ["location_id"], name: "index_service_requests_on_location_id"
    t.index ["status"], name: "index_service_requests_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "consent_at"
    t.datetime "created_at", null: false
    t.string "phone_e164"
    t.integer "role"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["phone_e164"], name: "index_users_on_phone_e164", unique: true
  end

  add_foreign_key "conversation_states", "service_requests"
  add_foreign_key "conversation_states", "users"
  add_foreign_key "leads", "service_requests"
  add_foreign_key "leads", "users", column: "provider_user_id"
  add_foreign_key "proposals", "service_requests"
  add_foreign_key "proposals", "users", column: "provider_user_id"
  add_foreign_key "provider_profiles", "users"
  add_foreign_key "ratings", "leads"
  add_foreign_key "reports", "users", column: "reporter_user_id"
  add_foreign_key "reports", "users", column: "target_user_id"
  add_foreign_key "service_requests", "users", column: "client_user_id"
end
