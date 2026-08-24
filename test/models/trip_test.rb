require "test_helper"

class TripTest < ActiveSupport::TestCase
  test "upcoming excludes trips that have ended" do
    assert_includes Trip.upcoming, trips(:lisbon)
    assert_not_includes Trip.upcoming, trips(:kyoto)
  end

  test "past includes only ended trips, newest first" do
    assert_includes Trip.past, trips(:kyoto)
    assert_not_includes Trip.past, trips(:lisbon)
  end

  test "past? reflects the end date" do
    assert trips(:kyoto).past?
    assert_not trips(:lisbon).past?
  end

  test "end date cannot precede start date" do
    trip = Trip.new(name: "Backwards", start_date: Date.new(2026, 5, 10), end_date: Date.new(2026, 5, 1))
    assert_not trip.valid?
    assert_includes trip.errors[:end_date], "can't be before the start date"
  end

  test "ordered_segments puts timed segments first, undated last" do
    trip = trips(:lisbon)
    ordered = trip.ordered_segments.to_a
    assert_equal segments(:lisbon_flight), ordered.first
    assert_equal segments(:lisbon_hotel), ordered.last
  end
end
