class AddNotesToTripsAndSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :notes, :text     # itinerary plan, logistics, anything freeform
    add_column :segments, :notes, :text  # per-booking detail: price, vehicle length, site number
  end
end
