require "test_helper"

class NotesTest < ActiveSupport::TestCase
  test "a trip carries free-text notes" do
    trip = trips(:lisbon)
    trip.update!(notes: "## Plan\n- Day 1")
    assert_equal "## Plan\n- Day 1", trip.reload.notes
  end

  test "a segment carries free-text notes" do
    segment = segments(:lisbon_flight)
    segment.update!(notes: "31' long, $252 including driver + 2 passengers")
    assert_match(/\$252/, segment.reload.notes)
  end
end
