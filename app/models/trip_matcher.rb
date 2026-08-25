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
    dates = extracted_dates
    return nil if dates.empty?
    scored = Trip.fileable.map { |t| [ t, dates.count { |d| (t.start_date..t.end_date).cover?(d) } ] }
    trip, hits = scored.max_by { |(_, n)| n }
    hits.to_i.positive? ? trip : nil
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
