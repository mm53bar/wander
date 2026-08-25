# Turns a booking email into a proposed itinerary segment using an LLM, for the
# human to review before saving. This is what the old nanoclaw pipeline did,
# moved into the app. Degrades to nil (→ manual entry) when the LLM isn't
# configured or the response is unusable.
class BookingParser
  SYSTEM = <<~PROMPT.freeze
    You extract ONE travel itinerary segment from a booking email (often a
    forwarded confirmation). Return ONLY a JSON object with these keys:
      kind            short lowercase type: flight, hotel, ferry, train,
                      car_rental, campsite, activity, check_in, check_out, note
      summary         one concise line naming the booking
      starts_at       ISO8601 datetime, or null
      ends_at         ISO8601 datetime, or null
      starts_at_label the email's own wording for the start time, or null
      ends_at_label   the email's own wording for the end time, or null
      location        place/address, or null
      confirmation    booking/confirmation number, or null
      links           array of {label, url}, or []
    Use the trip context to resolve relative or year-ambiguous dates. Preserve
    the email's original time wording in the *_label fields. Use null for
    anything not clearly present. Return JSON only, no commentary.
  PROMPT

  def initialize(email, trip, client: LlmClient.from_env)
    @email = email
    @trip = trip
    @client = client
  end

  def available?
    @client.configured?
  end

  # A hash of Segment attributes, or nil if drafting isn't possible.
  def segment_attrs
    data = @client.complete_json(system: SYSTEM, user: user_prompt)
    return nil unless data.is_a?(Hash)

    {
      kind: data["kind"].presence || "note",
      summary: data["summary"].presence || @email.subject.presence || "Booking",
      starts_at: data["starts_at"].presence,
      ends_at: data["ends_at"].presence,
      starts_at_label: data["starts_at_label"].presence,
      ends_at_label: data["ends_at_label"].presence,
      location: data["location"].presence,
      confirmation: data["confirmation"].presence,
      links: normalize_links(data["links"])
    }
  end

  private

  def user_prompt
    <<~TEXT
      TRIP: #{@trip.name} (#{@trip.start_date} to #{@trip.end_date}).

      EMAIL:
      Subject: #{@email.subject}
      From: #{@email.from_address}

      #{@email.body}
    TEXT
  end

  def normalize_links(value)
    Array(value).filter_map do |h|
      next unless h.is_a?(Hash)
      url = h["url"].presence
      { "label" => h["label"].presence || url, "url" => url } if url
    end
  end
end
