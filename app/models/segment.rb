class Segment < ApplicationRecord
  belongs_to :trip
  has_one :qr_code, dependent: :destroy

  validates :kind, :summary, presence: true

  # A sensible default glyph per kind, used only when the caller doesn't supply
  # one. Unknown kinds fall back to the clipboard the DB column defaults to.
  # Every kind the LLM prompts offer must appear here, or drafted segments come
  # out as clipboards — `car_rental` and `campsite` did exactly that.
  EMOJI_BY_KIND = {
    "flight" => "✈️", "hotel" => "🏨", "lodging" => "🏨", "train" => "🚆",
    "car" => "🚗", "rental_car" => "🚗", "car_rental" => "🚗", "ferry" => "⛴️",
    "bus" => "🚌", "transfer" => "🚐", "parking" => "🅿️",
    "campsite" => "🏕️", "camping" => "🏕️",
    "check_in" => "🔑", "check_out" => "🧳",
    "activity" => "🎟️", "restaurant" => "🍽️", "meeting" => "📅", "note" => "📝"
  }.freeze

  before_validation :assign_default_emoji

  # The link list is stored as an array of {"label" =>, "url" =>} hashes. Expose
  # it as small structs so views don't reach into raw hashes.
  Link = Data.define(:label, :url)

  def link_list
    Array(links).filter_map do |h|
      url = h["url"].presence || h[:url].presence
      next if url.blank?
      Link.new(label: h["label"].presence || h[:label].presence || url, url: url)
    end
  end

  # The local calendar date this segment falls on, preferring the human label
  # (which carries the segment's own time zone) over the stored UTC instant.
  def local_date
    if starts_at_label.present? && (parsed = date_from_label(starts_at_label))
      parsed
    elsif starts_at.present?
      starts_at.to_date
    end
  end

  # Reassign this segment to another trip.
  def move_to(trip)
    update!(trip: trip)
  end

  # Split this segment out into a brand-new trip of its own, seeded from the
  # segment's own date (fallbacks: its instant, then the current trip's dates).
  # Used to separate bookings that were lumped into one trip.
  def split_into_new_trip!(name: nil)
    on = local_date || starts_at&.to_date || trip.start_date
    new_trip = Trip.create!(
      name: name.presence || summary.to_s.truncate(60).presence || "New trip",
      start_date: on, end_date: (ends_at&.to_date || on)
    )
    update!(trip: new_trip)
    new_trip
  end

  private

  def assign_default_emoji
    return if emoji.present? && emoji != "📋"
    mapped = EMOJI_BY_KIND[kind.to_s.strip.downcase]
    self.emoji = mapped if mapped
  end

  # Pull "Mar 9" out of a label like "Mar 9, 8:00 PM MDT", using the stored
  # instant only to disambiguate the year.
  def date_from_label(label)
    m = label.match(/\A([A-Za-z]{3})\s+(\d{1,2})/)
    return nil unless m
    month = Date::ABBR_MONTHNAMES.index(m[1].capitalize)
    return nil unless month
    year = (starts_at || Time.current).year
    Date.new(year, month, m[2].to_i)
  rescue Date::Error
    nil
  end
end
