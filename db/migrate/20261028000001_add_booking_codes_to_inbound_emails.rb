class AddBookingCodesToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    add_column :inbound_emails, :booking_codes, :json, default: [], null: false
  end
end
