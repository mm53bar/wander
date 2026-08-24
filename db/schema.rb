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

ActiveRecord::Schema[8.1].define(version: 2026_08_23_000001) do
  create_table "qr_codes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "image_data", null: false
    t.integer "segment_id", null: false
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.index ["segment_id"], name: "index_qr_codes_on_segment_id", unique: true
  end

  create_table "raw_emails", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "from_address"
    t.datetime "received_at", null: false
    t.string "subject", null: false
    t.integer "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "received_at"], name: "index_raw_emails_on_trip_id_and_received_at"
    t.index ["trip_id"], name: "index_raw_emails_on_trip_id"
  end

  create_table "segments", force: :cascade do |t|
    t.string "confirmation"
    t.datetime "created_at", null: false
    t.string "emoji", default: "📋", null: false
    t.datetime "ends_at"
    t.string "ends_at_label"
    t.string "kind", null: false
    t.json "links", default: [], null: false
    t.string "location"
    t.datetime "starts_at"
    t.string "starts_at_label"
    t.string "summary", null: false
    t.integer "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "starts_at"], name: "index_segments_on_trip_id_and_starts_at"
    t.index ["trip_id"], name: "index_segments_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.string "booked_via"
    t.string "booking_ref"
    t.datetime "created_at", null: false
    t.string "destination"
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "travellers"
    t.datetime "updated_at", null: false
    t.index ["end_date"], name: "index_trips_on_end_date"
    t.index ["start_date"], name: "index_trips_on_start_date"
  end

  add_foreign_key "qr_codes", "segments", on_delete: :cascade
  add_foreign_key "raw_emails", "trips", on_delete: :cascade
  add_foreign_key "segments", "trips", on_delete: :cascade
end
