class CreateTravelSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.string :name, null: false
      t.string :destination
      t.date   :start_date, null: false
      t.date   :end_date, null: false
      t.string :travellers
      t.string :booking_ref
      t.string :booked_via
      t.timestamps
    end
    add_index :trips, :end_date
    add_index :trips, :start_date

    create_table :segments do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }
      # "kind" not "type": `type` is reserved by Active Record for STI.
      t.string  :kind, null: false
      t.string  :emoji, null: false, default: "📋"
      t.string  :summary, null: false
      # Absolute instant (UTC) used for ordering and the calendar export...
      t.datetime :starts_at
      t.datetime :ends_at
      # ...plus the exact wording the booking used, e.g. "Mar 9, 8:00 PM MDT",
      # preserved so a segment in another time zone reads the way the ticket does.
      t.string  :starts_at_label
      t.string  :ends_at_label
      t.string  :location
      t.string  :confirmation
      # Free-form list of {label, url} link hashes (directions, website, etc.).
      t.json    :links, null: false, default: []
      t.timestamps
    end
    add_index :segments, [ :trip_id, :starts_at ]

    create_table :qr_codes do |t|
      t.references :segment, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.text   :image_data, null: false   # base64-encoded PNG, rendered as a data: URI
      t.string :source_url
      t.timestamps
    end

    create_table :raw_emails do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }
      t.string   :from_address
      t.string   :subject, null: false
      t.text     :body, null: false
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :raw_emails, [ :trip_id, :received_at ]
  end
end
