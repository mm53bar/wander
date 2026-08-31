# Given an email's text, works out which existing trip it relates to — used to
# keep the inbox tidy and to default the "file to trip" choice.
#
#   * duplicate_trip: this booking is ALREADY recorded — an existing segment's
#     confirmation number appears verbatim in the email. Precise; used to
#     auto-resolve re-captured/forwarded copies.
#   * suggested_trip: no confirmation match, but the dates the email mentions
#     fall inside a trip's window — the best default when filing.
class TripMatcher
  MONTHS = %w[jan feb mar apr may jun jul aug sep oct nov dec].freeze

  # Bookings that stitch onto a trip often land just outside its dates — a ferry
  # the morning after a checkout, a hotel the night before a flight. Dates this
  # close to an edge still count, at half the weight of one inside, so a trip
  # that genuinely contains the booking always outranks a merely adjacent one.
  LEEWAY_DAYS = 3

  # first_date/last_date cover only the dates near THIS trip, not every date in
  # the email — a "Booking Date" line months earlier must not read as a booking
  # that starts before the trip does.
  Match = Data.define(:trip, :score, :inside, :near, :first_date, :last_date) do
    def inside? = inside.positive?
    def extends_end? = last_date > trip.end_date
    def extends_start? = first_date < trip.start_date
  end

  def initialize(text)
    @text = text.to_s
  end

  def duplicate_trip
    Segment.includes(:trip).where.not(confirmation: [ nil, "" ]).each do |seg|
      code = seg.confirmation.to_s.strip
      next if code.length < 6 # too short to be a safe unique key
      return seg.trip if @text.match?(/(?<![A-Za-z0-9])#{Regexp.escape(code)}(?![A-Za-z0-9])/)
    end
    nil
  end

  def suggested_trip
    best_match(Trip.fileable)&.trip
  end

  # The best-scoring trip for this email's dates, or nil when nothing scores or
  # two trips tie. A tie is real ambiguity — a booking equally adjacent to the
  # trip ending Friday and the one starting Monday — and naming either would
  # dress a coin flip up as a computation.
  def best_match(trips)
    dates = extracted_dates
    return nil if dates.empty?

    scored = trips.filter_map { |trip| score_for(trip, dates) }
    return nil if scored.empty?

    best = scored.max_by(&:score)
    scored.one? { |m| m.score == best.score } ? best : nil
  end

  # Dates mentioned in the email, in a few common formats, sanity-bounded.
  def extracted_dates
    found = []
    # 2026-09-06
    @text.scan(/\b(\d{4})-(\d{2})-(\d{2})\b/) { |y, m, d| found << safe_date(y, m, d) }
    # 6 Sep 2026  /  06 September 2026
    @text.scan(/\b(\d{1,2})\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})\b/) { |d, mon, y| found << month_date(y, mon, d) }
    # Sep 6, 2026  /  September 6 2026
    @text.scan(/\b([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})\b/) { |mon, d, y| found << month_date(y, mon, d) }
    found.compact.uniq
  end

  private

  # nil when no date in the email comes near this trip at all.
  def score_for(trip, dates)
    span = trip.start_date..trip.end_date
    relevant = dates.select { |d| (span.begin - LEEWAY_DAYS..span.end + LEEWAY_DAYS).cover?(d) }
    return nil if relevant.empty?

    inside = relevant.count { |d| span.cover?(d) }
    Match.new(trip: trip, score: (inside * 2) + (relevant.size - inside), inside: inside,
              near: relevant.size - inside, first_date: relevant.min, last_date: relevant.max)
  end

  def month_date(year, month_name, day)
    idx = MONTHS.index(month_name.to_s[0, 3].downcase)
    idx && safe_date(year, idx + 1, day)
  end

  def safe_date(year, month, day)
    d = Date.new(year.to_i, month.to_i, day.to_i)
    d if d.year.between?(Date.current.year - 3, Date.current.year + 3)
  rescue Date::Error
    nil
  end
end
