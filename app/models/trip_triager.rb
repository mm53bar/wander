# Full triage of a captured booking email: extract the segment AND decide where
# it belongs — an existing trip (optionally extending it), or a proposed new
# trip. This is the LLM layer; the deterministic confirmation-number match runs
# first (see TripMatcher / InboundEmail), so this only handles genuinely-new
# bookings. Returns a proposal hash, or nil if unavailable/unparseable.
class TripTriager
  SYSTEM = <<~PROMPT.freeze
    You triage a travel booking email. You are given the user's EXISTING TRIPS,
    each with its segments (type, date, location), and one booking EMAIL.

    Return ONLY JSON:
    {"segment":{"kind","summary","starts_at","ends_at","starts_at_label",
      "ends_at_label","location","confirmation","links":[{"label","url"}]},
     "assignment":{"trip_id":<existing id or null>,"extends_trip":true|false,
      "suggested_end_date":<ISO date or null>,
      "new_trip":{"name","start_date","end_date"}|null,
      "confidence":"high|medium|low","reason":"one sentence"}}

    Choosing a trip:
    - PREFER attaching to an existing trip. A booking belongs to a trip when its
      dates fall within, or are immediately adjacent to (starting on or near the
      trip's last day), that trip's span AND its location is consistent with the
      trip's route — near an existing stop or the destination.
    - A booking may EXTEND a trip: if it starts on/near the last day and is in the
      same area as the final stop, attach it, set extends_trip=true and
      suggested_end_date=the booking's end date.
    - Propose a NEW trip only when the booking is a clearly separate journey: a
      different region, or a distinctly different time with no continuity.
    Times ISO8601; preserve the email's wording in the *_label fields; null for
    unknowns. JSON only.
  PROMPT

  def initialize(email, client: LlmClient.from_env, trips: nil)
    @email = email
    @client = client
    @trips = trips || Trip.unarchived.includes(:segments).order(:start_date)
  end

  def available?
    @client.configured?
  end

  def triage
    data = @client.complete_json(system: SYSTEM, user: user_prompt)
    return nil unless data.is_a?(Hash)

    seg = data["segment"] || {}
    a = data["assignment"] || {}
    {
      segment: normalize_segment(seg),
      trip_id: valid_trip_id(a["trip_id"]),
      new_trip: normalize_new_trip(a["new_trip"]),
      extends_trip: a["extends_trip"] == true,
      suggested_end_date: a["suggested_end_date"].presence,
      confidence: %w[high medium low].include?(a["confidence"]) ? a["confidence"] : "low",
      reason: a["reason"].presence
    }
  end

  private

  def valid_trip_id(id)
    id if id.present? && @trips.any? { |t| t.id == id.to_i } && id.to_i
  end

  def normalize_new_trip(nt)
    return nil unless nt.is_a?(Hash) && nt["name"].present?
    { "name" => nt["name"], "start_date" => nt["start_date"], "end_date" => nt["end_date"] }
  end

  def normalize_segment(seg)
    {
      "kind" => seg["kind"].presence || "note",
      "summary" => seg["summary"].presence || @email.subject.presence || "Booking",
      "starts_at" => seg["starts_at"].presence, "ends_at" => seg["ends_at"].presence,
      "starts_at_label" => seg["starts_at_label"].presence, "ends_at_label" => seg["ends_at_label"].presence,
      "location" => seg["location"].presence, "confirmation" => seg["confirmation"].presence,
      "links" => Array(seg["links"]).select { |h| h.is_a?(Hash) && h["url"].present? }
    }
  end

  def user_prompt
    trips = @trips.map { |t| trip_block(t) }.join("\n")
    body = @email.body.to_s[0, 6000]
    "EXISTING TRIPS:\n#{trips}\n\nEMAIL:\nSubject: #{@email.subject}\nFrom: #{@email.from_address}\n\n#{body}"
  end

  def trip_block(t)
    head = %(- id=#{t.id} "#{t.name}" [#{t.start_date}..#{t.end_date}] dest=#{t.destination.presence || "?"})
    segs = t.segments.map do |s|
      "    · #{s.kind} #{s.starts_at&.to_date || s.local_date} @ #{(s.location.presence || s.summary).to_s[0, 50]}"
    end
    ([ head ] + segs).join("\n")
  end
end
