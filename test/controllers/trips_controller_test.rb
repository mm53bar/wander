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

  test "show hides a segment's scan code behind a toggle that knows its scan days" do
    seg = segments(:lisbon_flight)
    get trip_path(trips(:lisbon))
    assert_select ".seg-qr[data-controller='scan-day collapsible'][data-scan-day-dates-value=?]", seg.scan_dates.to_json do
      assert_select "button[data-action='click->collapsible#toggle']", text: /Scan code/
      assert_select "[data-collapsible-target='content'][style*='max-height: 0'] img[src^='data:image/png']"
      assert_select "a[href='#qr-#{seg.id}'][data-turbo='false']"
      assert_select "a#qr-#{seg.id}.qr-full[data-turbo='false']"
    end
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

  test "notes are saved and rendered as markdown on the trip page" do
    patch trip_path(trips(:lisbon)), params: { trip: { notes: "## Plan\n\n- Sat 5 - leave for Kamloops" } }
    get trip_path(trips(:lisbon))
    assert_select "h2", text: "Plan"
    assert_select ".prose li", text: /leave for Kamloops/
  end
end
