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
end
