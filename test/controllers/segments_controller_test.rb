require "test_helper"

class SegmentsControllerTest < ActionDispatch::IntegrationTest
  test "json create adds a segment with links" do
    post trip_segments_path(trips(:lisbon), format: :json),
      params: { segment: { kind: "restaurant", summary: "Dinner",
                           links: [ { label: "Menu", url: "https://example.com/menu" } ] } }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :created
    assert_equal "🍽️", Segment.last.emoji
    assert_equal "Menu", Segment.last.link_list.first.label
  end

  test "html create from a form-style links hash drops blank rows" do
    assert_difference -> { Segment.count }, 1 do
      post trip_segments_path(trips(:lisbon)), params: { segment: {
        kind: "activity", summary: "Museum",
        links: { "0" => { label: "Tickets", url: "https://example.com" }, "1" => { label: "", url: "" } }
      } }
    end
    assert_equal 1, Segment.last.link_list.size
  end

  test "update edits a segment" do
    patch segment_path(segments(:lisbon_hotel)), params: { segment: { summary: "New Hotel" } }
    assert_equal "New Hotel", segments(:lisbon_hotel).reload.summary
  end

  test "destroy removes a segment" do
    assert_difference -> { Segment.count }, -1 do
      delete segment_path(segments(:lisbon_hotel))
    end
  end

  test "segment notes are saved and rendered on the trip page" do
    patch segment_path(segments(:lisbon_flight)), params: { segment: { notes: "$252 for the crossing" } }
    get trip_path(trips(:lisbon))
    assert_select ".seg-notes", text: /\$252 for the crossing/
  end
end
