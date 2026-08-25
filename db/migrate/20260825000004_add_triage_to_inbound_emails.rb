class AddTriageToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    change_table :inbound_emails, bulk: true do |t|
      t.json     :proposed_segment            # LLM-extracted segment attributes
      t.integer  :proposed_trip_id            # suggested existing trip (nil if new/none)
      t.json     :proposed_new_trip           # {name, start_date, end_date} if a new trip is proposed
      t.boolean  :extends_trip, default: false, null: false
      t.date     :suggested_end_date          # new trip end date if this booking extends it
      t.string   :confidence                  # high | medium | low
      t.text     :reason
      t.boolean  :auto_filed, default: false, null: false
      t.integer  :created_segment_id          # the segment we created (for undo)
    end
  end
end
