class CreateInboundEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :inbound_emails do |t|
      # Message-ID from the header — the dedup key so re-polling the mailbox
      # never captures the same message twice.
      t.string   :message_id, null: false
      t.string   :from_address
      t.string   :subject
      t.text     :body
      t.datetime :received_at, null: false
      # Why the classifier thought this was travel-related (for transparency in
      # the UI and when tuning the heuristic).
      t.json     :signals, null: false, default: []
      t.integer  :score, null: false, default: 0
      # received → sitting in the inbox; filed → turned into a trip's source
      # email; ignored → dismissed as a false positive.
      t.string   :status, null: false, default: "received"
      # Set when filed to a trip.
      t.references :trip, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :inbound_emails, :message_id, unique: true
    add_index :inbound_emails, :status
  end
end
