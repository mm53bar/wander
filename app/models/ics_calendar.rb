# Hand-rolled iCalendar (RFC 5545) writer — one VEVENT per timed segment. Kept
# dependency-free on purpose: the format we emit is small and stable, and a gem
# would be more surface than the handful of lines below.
class IcsCalendar
  PRODID = "-//wander//Travel//EN".freeze
  CALNAME = "Travel".freeze
  MAX_OCTETS = 75

  def initialize(segments, now: Time.current)
    @segments = segments
    @now = now
  end

  def to_ics
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:#{PRODID}",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "X-WR-CALNAME:#{CALNAME}"
    ]
    @segments.each { |segment| lines.concat(vevent(segment)) if segment.starts_at }
    lines << "END:VCALENDAR"
    # RFC 5545 requires CRLF line endings and a trailing one.
    lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private

  def vevent(segment)
    finish = segment.ends_at || segment.starts_at
    event = [
      "BEGIN:VEVENT",
      "UID:segment-#{segment.id}@wander",
      "DTSTAMP:#{ics_time(@now)}",
      "DTSTART:#{ics_time(segment.starts_at)}",
      "DTEND:#{ics_time(finish)}",
      "SUMMARY:#{escape("#{segment.emoji} #{segment.summary}".strip)}"
    ]
    event << "LOCATION:#{escape(segment.location)}" if segment.location.present?
    event << "DESCRIPTION:#{escape("Confirmation: #{segment.confirmation}")}" if segment.confirmation.present?
    event << "END:VEVENT"
    event
  end

  # UTC basic format: 20260309T200000Z
  def ics_time(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  # RFC 5545 caps a content line at 75 octets; longer ones continue on the next
  # line behind a single space. Octets, not characters — an emoji costs four —
  # and a multi-byte character must never be split across the break.
  def fold(line)
    return line if line.bytesize <= MAX_OCTETS

    folded = +""
    current = +""
    limit = MAX_OCTETS
    line.each_char do |char|
      if current.bytesize + char.bytesize > limit
        folded << current << "\r\n "
        current = +""
        limit = MAX_OCTETS - 1
      end
      current << char
    end
    folded << current
  end

  def escape(value)
    value.to_s.gsub("\\", "\\\\\\\\").gsub(";", "\;").gsub(",", "\\,").gsub("\n", "\\n")
  end
end
