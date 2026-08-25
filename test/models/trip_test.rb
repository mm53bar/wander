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
  test "archived trips are excluded from upcoming, past, and fileable" do
    trips(:lisbon).archive!
    assert_not_includes Trip.upcoming, trips(:lisbon)
    assert_not_includes Trip.fileable, trips(:lisbon)
    assert_includes Trip.archived, trips(:lisbon)
  end

  test "fileable is upcoming unarchived, soonest first" do
    assert_equal Trip.upcoming.to_a, Trip.fileable.to_a
    assert_not_includes Trip.fileable, trips(:kyoto) # past
  end

  test "label_with_dates includes name and dates" do
    assert_match(/Lisbon City Break —/, trips(:lisbon).label_with_dates)
  end

  test "archive! and unarchive! toggle archived_at" do
    t = trips(:lisbon)
    t.archive!
    assert t.reload.archived?
    t.unarchive!
    assert_not t.reload.archived?
  end
end
