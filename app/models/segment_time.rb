# Turns the wall-clock time an LLM read out of a booking email into an absolute
# instant. The model is never asked for the instant itself: identifying a zone is
# recall, which it does well, while applying a DST-correct offset is arithmetic,
# which it does inconsistently — the same email yielded -07:00 and -06:00 on
# successive runs. See docs/adr/20260829-deterministic-segment-times.md.
#
# Resolution order, first hit wins:
#   1. a zone abbreviation in the booking's own wording ("Sep 5, 3:00 PM PDT")
#   2. an IANA zone from the model, only if TZInfo actually knows it
#   3. a static table keyed off the segment's location
#   4. nothing — return nil and leave the segment undated rather than guess
class SegmentTime
  # An abbreviation IS an offset, so no DST reasoning is needed for step 1.
  # Ambiguous ones are deliberately absent — CST is -06:00 in Winnipeg and
  # +08:00 in Shanghai, IST is three different zones, BST two. They fall through
  # to a step that can tell the difference instead of guessing silently.
  OFFSETS = {
    "utc" => "+00:00", "gmt" => "+00:00",
    "nst" => "-03:30", "ndt" => "-02:30", "ast" => "-04:00", "adt" => "-03:00",
    "est" => "-05:00", "edt" => "-04:00", "cdt" => "-05:00",
    "mst" => "-07:00", "mdt" => "-06:00", "pst" => "-08:00", "pdt" => "-07:00",
    "akst" => "-09:00", "akdt" => "-08:00", "hst" => "-10:00",
    "cet" => "+01:00", "cest" => "+02:00", "wet" => "+00:00", "west" => "+01:00",
    "eet" => "+02:00", "eest" => "+03:00",
    "sgt" => "+08:00", "hkt" => "+08:00", "jst" => "+09:00", "kst" => "+09:00",
    "aest" => "+10:00", "aedt" => "+11:00", "awst" => "+08:00",
    "nzst" => "+12:00", "nzdt" => "+13:00"
  }.freeze

  # Step 3: a coarse fallback for places this household actually travels to.
  # Add rows as needed — an unlisted location yields an undated segment for
  # review, which is the intended failure, not a bug.
  ZONE_BY_LOCATION = {
    /\b(bc|british columbia|vancouver|victoria|parksville|qualicum|nanaimo|tofino|whistler|kamloops|kelowna|revelstoke)\b/ => "America/Vancouver",
    /\b(ab|alberta|calgary|edmonton|banff|jasper|canmore|lethbridge|yeg|yyc)\b/ => "America/Edmonton",
    /\b(sk|saskatchewan|saskatoon|regina)\b/ => "America/Regina",
    /\b(mb|manitoba|winnipeg)\b/ => "America/Winnipeg",
    /\b(on|ontario|toronto|ottawa|qc|quebec|montreal|yyz|yul)\b/ => "America/Toronto",
    /\b(ns|nova scotia|halifax|nb|new brunswick|pei)\b/ => "America/Halifax",
    /\b(nl|newfoundland|st\. john's)\b/ => "America/St_Johns",
    /\b(yt|yukon|whitehorse)\b/ => "America/Whitehorse",
    /\bsingapore\b/ => "Asia/Singapore",
    /\b(london|uk|england|scotland)\b/ => "Europe/London"
  }.freeze

  # The wording both LLM prompts use, so the two can't drift apart.
  PROMPT = <<~TEXT.freeze
    Times: give *_at_local as local wall-clock "YYYY-MM-DDTHH:MM" with NO offset
    and NO trailing Z — the time exactly as a traveller reads it off the booking.
    Give *_time_zone as an IANA identifier for where that event happens
    (e.g. America/Vancouver); a departure and an arrival may differ. Never compute
    a UTC offset yourself. Preserve the email's own wording in the *_label fields.
    Use null for anything not clearly present.
  TEXT

  # Resolve both ends of one LLM-proposed segment. The end falls back to the
  # start's zone, which is right for a stay and overridden for a journey.
  def self.from_llm(seg)
    location = seg["location"].presence
    {
      starts_at: resolve(local: seg["starts_at_local"], label: seg["starts_at_label"],
                         zone: seg["starts_time_zone"], location: location),
      ends_at: resolve(local: seg["ends_at_local"], label: seg["ends_at_label"],
                       zone: seg["ends_time_zone"].presence || seg["starts_time_zone"], location: location)
    }
  end

  # local: "2026-09-08T13:00" wall clock. Returns a Time, or nil when no zone
  # can be established.
  def self.resolve(local:, label: nil, zone: nil, location: nil)
    wall = wall_clock(local)
    return nil unless wall

    if (offset = offset_from_label(label))
      Time.parse("#{wall}#{offset}")
    elsif (tz = timezone(zone) || timezone_for(location))
      tz.parse(wall)
    end
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
    nil
  end

  # Any offset the model attached is dropped, not trusted — supplying one is the
  # arithmetic this class exists to take away from it.
  def self.wall_clock(local)
    m = local.to_s.strip.match(/\A(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/)
    m && "#{m[1]}T#{m[2]}"
  end

  def self.offset_from_label(label)
    token = label.to_s.downcase.scan(/\b[a-z]{2,4}\b/).find { |t| OFFSETS.key?(t) }
    OFFSETS[token]
  end

  def self.timezone(zone)
    return nil if zone.blank?
    ActiveSupport::TimeZone[zone.to_s]
  end

  def self.timezone_for(location)
    return nil if location.blank?
    haystack = location.to_s.downcase
    _, zone = ZONE_BY_LOCATION.find { |pattern, _| haystack.match?(pattern) }
    zone && ActiveSupport::TimeZone[zone]
  end
end
