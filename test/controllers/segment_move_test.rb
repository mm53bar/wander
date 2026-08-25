require "test_helper"

class SegmentMoveTest < ActionDispatch::IntegrationTest
  test "move form renders with other trips" do
    get move_segment_path(segments(:lisbon_hotel))
    assert_response :success
  end

  test "relocate moves the segment to an existing trip" do
    seg = segments(:lisbon_hotel)
    patch relocate_segment_path(seg), params: { target: "existing", trip_id: trips(:kyoto).id }
    assert_equal trips(:kyoto), seg.reload.trip
    assert_redirected_to trips(:kyoto)
  end

  test "relocate target=new splits into a fresh trip" do
    seg = segments(:lisbon_hotel)
    assert_difference -> { Trip.count }, 1 do
      patch relocate_segment_path(seg), params: { target: "new", new_name: "Just the hotel" }
    end
    assert_equal "Just the hotel", seg.reload.trip.name
    assert_redirected_to edit_trip_path(seg.trip)
  end

  test "split creates a new trip from the segment" do
    seg = segments(:lisbon_flight)
    assert_difference -> { Trip.count }, 1 do
      post split_segment_path(seg)
    end
    assert_not_equal trips(:lisbon), seg.reload.trip
  end
end
