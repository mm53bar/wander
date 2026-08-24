json.partial! "trips/trip", trip: @trip
json.raw_emails @trip.raw_emails.order(:received_at) do |email|
  json.id email.id
  json.from_address email.from_address
  json.subject email.subject
  json.body email.body
  json.received_at email.received_at
end
