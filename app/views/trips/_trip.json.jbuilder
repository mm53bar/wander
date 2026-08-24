json.id trip.id
json.name trip.name
json.destination trip.destination
json.start_date trip.start_date
json.end_date trip.end_date
json.travellers trip.travellers
json.booking_ref trip.booking_ref
json.booked_via trip.booked_via
json.past trip.past?
json.segments trip.ordered_segments, partial: "segments/segment", as: :segment
