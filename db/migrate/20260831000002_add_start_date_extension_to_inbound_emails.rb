class AddStartDateExtensionToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    change_table :inbound_emails, bulk: true do |t|
      # A booking can extend a trip backwards as well as forwards, now that a
      # date just before the start counts as a match.
      t.date :suggested_start_date
      t.date :prior_trip_start_date # what an auto-filed extend moved, for undo
    end
  end
end
