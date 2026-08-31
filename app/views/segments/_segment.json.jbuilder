json.id segment.id
json.trip_id segment.trip_id
json.kind segment.kind
json.emoji segment.emoji
json.summary segment.summary
json.starts_at segment.starts_at
json.ends_at segment.ends_at
json.starts_at_label segment.starts_at_label
json.ends_at_label segment.ends_at_label
json.location segment.location
json.confirmation segment.confirmation
json.notes segment.notes
json.links segment.link_list do |link|
  json.label link.label
  json.url link.url
end
if segment.qr_code
  json.qr_code do
    json.source_url segment.qr_code.source_url
    json.image_data segment.qr_code.image_data
  end
end
