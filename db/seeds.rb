# Reference data + (in development) sample content.
#
# Safe senders are seeded in EVERY environment — they're the reference list the
# email classifier matches against, and idempotent so a redeploy tops them up
# without clobbering anything you've added or removed.
SafeSender.seed_defaults!
puts "Safe senders: #{SafeSender.count}."

# Sample trips are development-only: a public checkout shows something useful,
# but production stays empty (its data is migrated/created for real). Fictional
# on purpose — generic destinations, made-up confirmation codes.
if Rails.env.development?
  Trip.destroy_all

  SAMPLE_QR = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"

  def at(days_from_now, hour, minute = 0)
    (Date.current + days_from_now).to_time(:utc).change(hour: hour, min: minute)
  end

  lisbon = Trip.create!(
    name: "Lisbon City Break", destination: "Lisbon, Portugal",
    start_date: Date.current + 21, end_date: Date.current + 26,
    travellers: "Two adults", booked_via: "Example Airlines", booking_ref: "LIS4RT"
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
    links: [ { "label" => "Directions", "url" => "https://example.com/maps/baixa-boutique" } ]
  )
  lisbon.raw_emails.create!(
    from_address: "bookings@example.com", subject: "Your Lisbon itinerary is confirmed",
    received_at: Time.current - 3.days,
    body: "Thanks for booking!\n\nConfirmation: LIS4RT\nEX204 LHR->LIS.\n\nBon voyage!"
  )

  kyoto = Trip.create!(
    name: "Kyoto in Autumn", destination: "Kyoto, Japan",
    start_date: Date.current - 90, end_date: Date.current - 80, travellers: "Two adults"
  )
  kyoto.segments.create!(
    kind: "flight", summary: "EX88 — London (LHR) → Osaka (KIX)",
    starts_at: (Date.current - 90).to_time(:utc).change(hour: 11),
    starts_at_label: "#{(Date.current - 90).strftime('%b %-d')}, 11:00 AM GMT",
    location: "Heathrow Terminal 2", confirmation: "KYO-2233"
  )

  puts "Dev sample: #{Trip.count} trips, #{Segment.count} segments."
end
