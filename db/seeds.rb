# Sample data so a fresh clone shows something meaningful. Entirely fictional —
# generic destinations and made-up confirmation codes, safe for a public repo.
# Dates are generated relative to today so the demo always has upcoming trips.
#
# Idempotent: clears and reloads. Run with `bin/rails db:seed` (or
# `db:seed:replant` to reset first).

Trip.destroy_all

# A 1x1 transparent PNG, base64 — stands in for a real booking QR code.
SAMPLE_QR = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"

def at(days_from_now, hour, minute = 0)
  (Date.current + days_from_now).to_time(:utc).change(hour: hour, min: minute)
end

lisbon = Trip.create!(
  name: "Lisbon City Break",
  destination: "Lisbon, Portugal",
  start_date: Date.current + 21,
  end_date: Date.current + 26,
  travellers: "Two adults",
  booked_via: "Example Airlines",
  booking_ref: "LIS4RT"
)
flight = lisbon.segments.create!(
  kind: "flight", summary: "EX204 — London (LHR) → Lisbon (LIS)",
  starts_at: at(21, 9, 40), ends_at: at(21, 12, 55),
  starts_at_label: "#{(Date.current + 21).strftime('%b %-d')}, 9:40 AM BST",
  ends_at_label: "#{(Date.current + 21).strftime('%b %-d')}, 12:55 PM WEST",
  location: "Heathrow Terminal 5", confirmation: "LIS4RT",
  links: [ { "label" => "Flight status", "url" => "https://example.com/flights/EX204" } ]
)
flight.create_qr_code!(image_data: SAMPLE_QR, source_url: "https://example.com/boarding/EX204")
lisbon.segments.create!(
  kind: "hotel", summary: "Baixa Boutique Hotel — 5 nights",
  starts_at: at(21, 15), starts_at_label: "#{(Date.current + 21).strftime('%b %-d')}, 3:00 PM WEST",
  location: "Rua Augusta, Baixa", confirmation: "HZ-88213",
  links: [ { "label" => "Directions", "url" => "https://example.com/maps/baixa-boutique" },
           { "label" => "Website", "url" => "https://example.com/baixa-boutique" } ]
)
lisbon.segments.create!(
  kind: "activity", summary: "Sintra day trip — Pena Palace tickets",
  starts_at: at(23, 10), starts_at_label: "#{(Date.current + 23).strftime('%b %-d')}, 10:00 AM WEST",
  location: "Sintra", confirmation: "PENA-4471"
)
lisbon.raw_emails.create!(
  from_address: "bookings@example.com", subject: "Your Lisbon itinerary is confirmed",
  received_at: Time.current - 3.days,
  body: "Thanks for booking with Example Airlines!\n\nConfirmation: LIS4RT\nEX204 LHR->LIS, seats 14A/14B.\n\nBon voyage!"
)

weekend = Trip.create!(
  name: "Amsterdam Long Weekend",
  destination: "Amsterdam, Netherlands",
  start_date: Date.current + 60, end_date: Date.current + 63,
  travellers: "Solo"
)
weekend.segments.create!(
  kind: "train", summary: "Eurostar — London → Amsterdam Centraal",
  starts_at: at(60, 8, 16), ends_at: at(60, 12, 47),
  starts_at_label: "#{(Date.current + 60).strftime('%b %-d')}, 8:16 AM BST",
  location: "St Pancras International", confirmation: "EUS-7781A"
)
weekend.segments.create!(
  kind: "hotel", summary: "Canal View Inn — 3 nights",
  starts_at: at(60, 15), location: "Jordaan"
)

kyoto = Trip.create!(
  name: "Kyoto in Autumn",
  destination: "Kyoto, Japan",
  start_date: Date.current - 90, end_date: Date.current - 80,
  travellers: "Two adults", booked_via: "Example Travel Co", booking_ref: "KYO-2233"
)
kyoto.segments.create!(
  kind: "flight", summary: "EX88 — London (LHR) → Osaka (KIX)",
  starts_at: (Date.current - 90).to_time(:utc).change(hour: 11),
  starts_at_label: "#{(Date.current - 90).strftime('%b %-d')}, 11:00 AM GMT",
  location: "Heathrow Terminal 2", confirmation: "KYO-2233"
)
kyoto.segments.create!(
  kind: "activity", summary: "Arashiyama Bamboo Grove walk",
  starts_at: (Date.current - 86).to_time(:utc).change(hour: 9),
  location: "Arashiyama"
)

puts "Seeded #{Trip.count} trips, #{Segment.count} segments, #{RawEmail.count} emails, #{QrCode.count} QR codes."
