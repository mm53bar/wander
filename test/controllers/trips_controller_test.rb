require "test_helper"

class TripsControllerTest < ActionDispatch::IntegrationTest
  test "index renders upcoming and past" do
    get root_path
    assert_response :success
    assert_select "article.trip-card", text: /Lisbon City Break/
  end

  test "show renders a trip" do
    get trip_path(trips(:lisbon))
    assert_response :success
    assert_select "h1", text: /Lisbon City Break/
  end

  test "html create redirects to the trip" do
    assert_difference -> { Trip.count }, 1 do
      post trips_path, params: { trip: { name: "Rome", start_date: "2026-10-01", end_date: "2026-10-05" } }
    end
    assert_redirected_to Trip.last
  end

  test "json create returns 201 with the trip" do
    post trips_path(format: :json),
      params: { trip: { name: "Berlin", start_date: "2026-10-01", end_date: "2026-10-05" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :created
    assert_equal "Berlin", response.parsed_body["name"]
  end

  test "json create with invalid data returns 422 and errors" do
    post trips_path(format: :json), params: { trip: { name: "" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].key?("name")
  end

  test "update changes attributes" do
    patch trip_path(trips(:lisbon)), params: { trip: { destination: "Porto" } }
    assert_equal "Porto", trips(:lisbon).reload.destination
  end

  test "destroy removes the trip and its segments" do
    seg_id = segments(:lisbon_flight).id
    assert_difference -> { Trip.count }, -1 do
      delete trip_path(trips(:lisbon))
    end
    assert_not Segment.exists?(seg_id)
  end
  test "archive and unarchive a trip" do
    post archive_trip_path(trips(:lisbon))
    assert trips(:lisbon).reload.archived?
    post unarchive_trip_path(trips(:lisbon))
    assert_not trips(:lisbon).reload.archived?
  end
end
