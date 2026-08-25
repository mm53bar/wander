module InboundEmailsHelper
  # Trip <option>s for accepting a proposal: existing fileable trips, with the
  # proposed trip pre-selected. When a NEW trip is proposed, a blank-value option
  # (→ create it) leads and is selected by default.
  def trip_options_for(email)
    existing = options_from_collection_for_select(Trip.fileable, :id, :label_with_dates, email.proposed_trip_id)
    if email.proposed_new_trip.present? && email.proposed_trip_id.blank?
      nt = email.proposed_new_trip
      label = "➕ New trip: #{nt['name']} (#{nt['start_date']}–#{nt['end_date']})"
      tag.option(label, value: "", selected: true) + existing
    else
      existing
    end
  end
end
