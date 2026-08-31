require "test_helper"

class TripMatcherTest < ActiveSupport::TestCase
  test "duplicate_trip matches an existing segment's confirmation in the text" do
    # lisbon_flight fixture has confirmation "LIS4RT"
    trip = TripMatcher.new("Fwd: your booking\nConfirmation: LIS4RT for your flight").duplicate_trip
    assert_equal trips(:lisbon), trip
  end

  test "duplicate_trip ignores confirmations shorter than 6 chars and partial matches" do
    assert_nil TripMatcher.new("code XLIS4RTY embedded").duplicate_trip # not word-bounded
  end

  test "suggested_trip picks the trip whose range covers the mentioned dates" do
    d = (22.days.from_now.to_date).iso8601  # inside lisbon's 20..25-day window
    assert_equal trips(:lisbon), TripMatcher.new("Your stay on #{d} is confirmed").suggested_trip
  end

  test "suggested_trip returns nil when no dates land in any trip" do
    assert_nil TripMatcher.new("Your stay on 1999-01-01").suggested_trip
  end

  test "extracts several date formats" do
    dates = TripMatcher.new("2026-09-06, 6 Sep 2026, September 6, 2026").extracted_dates
    assert_includes dates, Date.new(2026, 9, 6)
  end

  # lisbon runs 20..25 days out; kyoto is long finished.
  def matcher_for(*days_out)
    TripMatcher.new(days_out.map { |d| d.days.from_now.to_date.iso8601 }.join(" and "))
  end

  test "a date just outside a trip still matches, at half weight" do
    match = matcher_for(27).best_match(Trip.fileable)   # 2 days past the end
    assert_equal trips(:lisbon), match.trip
    assert_equal 0, match.inside
    assert_equal 1, match.near
    assert match.extends_end?
  end

  test "beyond the leeway it stops matching" do
    assert_nil matcher_for(25 + TripMatcher::LEEWAY_DAYS + 1).best_match(Trip.fileable)
  end

  test "a trip containing the dates outranks one merely adjacent" do
    other = Trip.create!(name: "Adjacent", start_date: 27.days.from_now.to_date, end_date: 30.days.from_now.to_date)
    match = matcher_for(24).best_match(Trip.fileable)   # inside lisbon, within 3 days of other
    assert_equal trips(:lisbon), match.trip, "containment must beat adjacency"
    assert_operator match.score, :>, 1
    other.destroy
  end

  test "no match when two trips tie rather than guessing between them" do
    # Equally adjacent: 1 day after lisbon ends, 1 day before the next begins.
    Trip.create!(name: "Next up", start_date: 28.days.from_now.to_date, end_date: 31.days.from_now.to_date)
    assert_nil matcher_for(26).best_match(Trip.fileable)
  end

  test "a stray booking-date line doesn't drag the match window backwards" do
    # "Booking Date" months before the trip must not read as an early start.
    match = matcher_for(-40, 22, 24).best_match(Trip.fileable)
    assert_equal trips(:lisbon), match.trip
    assert_not match.extends_start?, "the far-off date is not near this trip"
    assert_equal 22.days.from_now.to_date, match.first_date
  end

  test "suggested_trip still answers with just the trip" do
    assert_equal trips(:lisbon), matcher_for(22).suggested_trip
  end
end
