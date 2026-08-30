class AddPriorTripEndDateToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    # The trip end date an auto-filed extend moved, so undo can put it back.
    add_column :inbound_emails, :prior_trip_end_date, :date
  end
end
