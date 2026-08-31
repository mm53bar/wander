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
    {"segment":{"kind","summary","starts_at_local","starts_time_zone",
      "ends_at_local","ends_time_zone","starts_at_label","ends_at_label",
      "location","confirmation","links":[{"label","url"}]},
     "assignment":{"trip_id":<existing id or null>,"extends_trip":true|false,
      "suggested_start_date":<ISO date or null>,"suggested_end_date":<ISO date or null>,
      "new_trip":{"name","start_date","end_date"}|null,
      "confidence":"high|medium|low","reason":"one sentence"}}

    Choosing a trip:
    - A DATE MATCH line, when present, is a deterministic computation over the
      email's dates. Trust it over your own reading of them: attach to the trip it
      names unless that trip's location is clearly inconsistent with the booking.
    - PREFER attaching to an existing trip. A booking belongs to a trip when its
      dates fall within, or are immediately adjacent to (starting on or near the
      trip's last day), that trip's span AND its location is consistent with the
      trip's route — near an existing stop or the destination.
    - A booking may EXTEND a trip at either end: if it sits on or just outside the
      trip's first or last day and is in the same area as the nearest stop, attach
      it, set extends_trip=true, and give suggested_end_date (booking's end date)
      or suggested_start_date (booking's start date) for whichever edge it passes.
    - Propose a NEW trip only when the booking is a clearly separate journey: a
      different region, or a distinctly different time with no continuity.
    #{SegmentTime::PROMPT}
    JSON only.
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
      suggested_start_date: a["suggested_start_date"].presence,
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

  # The wall-clock times become instants here, at the boundary where LLM output
  # enters the system, so everything downstream sees a real instant or nil. The
  # *_at_local values are kept so an unresolved zone stays distinguishable from a
  # booking that simply states no time (see InboundEmail#proposed_start_resolved?).
  def normalize_segment(seg)
    times = SegmentTime.from_llm(seg)
    {
      "kind" => seg["kind"].presence || "note",
      "summary" => seg["summary"].presence || @email.subject.presence || "Booking",
      "starts_at" => times[:starts_at]&.iso8601, "ends_at" => times[:ends_at]&.iso8601,
      "starts_at_local" => seg["starts_at_local"].presence, "ends_at_local" => seg["ends_at_local"].presence,
      "starts_at_label" => seg["starts_at_label"].presence, "ends_at_label" => seg["ends_at_label"].presence,
      "location" => seg["location"].presence, "confirmation" => seg["confirmation"].presence,
      "links" => Array(seg["links"]).select { |h| h.is_a?(Hash) && h["url"].present? }
    }
  end

  def user_prompt
    trips = @trips.map { |t| trip_block(t) }.join("\n")
    body = @email.body.to_s[0, 6000]
    email = "EMAIL:\nSubject: #{@email.subject}\nFrom: #{@email.from_address}\n\n#{body}"
    [ "EXISTING TRIPS:\n#{trips}", date_hint, email ].compact.join("\n\n")
  end

  # TripMatcher's date read, handed to the model rather than left for it to work
  # out: a booking starting on a trip's last day reads as "no overlap" to the LLM
  # often enough that it proposes a spurious new trip.
  def date_hint
    # Only trips that haven't ended: an email's booking-date line ("Booking Date
    # Sunday, August 23") lands inside whatever trip was running that week, and a
    # finished trip must not out-score the one the booking is actually for.
    candidates = @trips.reject { |t| t.end_date < Date.current }
    match = TripMatcher.new("#{@email.subject}\n#{@email.body}").best_match(candidates)
    return nil unless match

    ([ match_summary(match) ] + extend_notes(match)).join(" ")
  end

  def match_summary(match)
    trip = match.trip
    span = "trip id=#{trip.id} \"#{trip.name}\" [#{trip.start_date}..#{trip.end_date}]"
    if match.inside?
      "DATE MATCH: #{match.inside} of the email's dates fall inside #{span}."
    else
      "DATE MATCH: the email's dates sit within #{TripMatcher::LEEWAY_DAYS} days of #{span}, " \
        "just outside it."
    end
  end

  def extend_notes(match)
    trip = match.trip
    notes = []
    if match.extends_end?
      notes << "It runs to #{match.last_date}, past that trip's end date (#{trip.end_date}) — " \
               "treat it as an EXTENDS case with suggested_end_date=#{match.last_date}."
    end
    if match.extends_start?
      notes << "It starts #{match.first_date}, before that trip's start date (#{trip.start_date}) — " \
               "treat it as an EXTENDS case with suggested_start_date=#{match.first_date}."
    end
    notes
  end

  def trip_block(t)
    head = %(- id=#{t.id} "#{t.name}" [#{t.start_date}..#{t.end_date}] dest=#{t.destination.presence || "?"})
    segs = t.segments.map do |s|
      "    · #{s.kind} #{s.starts_at&.to_date || s.local_date} @ #{(s.location.presence || s.summary).to_s[0, 50]}"
    end
    ([ head ] + segs).join("\n")
  end
end
