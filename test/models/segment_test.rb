require "test_helper"

class SegmentTest < ActiveSupport::TestCase
  test "a default emoji is assigned from the kind when none is given" do
    segment = trips(:lisbon).segments.new(kind: "flight", summary: "Test")
    segment.valid?
    assert_equal "✈️", segment.emoji
  end

  test "an explicit emoji is preserved" do
    segment = trips(:lisbon).segments.new(kind: "flight", emoji: "🛩️", summary: "Test")
    segment.valid?
    assert_equal "🛩️", segment.emoji
  end

  test "link_list exposes label/url structs and drops blank urls" do
    segment = Segment.new(links: [
      { "label" => "Website", "url" => "https://example.com" },
      { "label" => "Empty", "url" => "" },
      { "url" => "https://noname.example" }
    ])
    links = segment.link_list
    assert_equal 2, links.size
    assert_equal "Website", links.first.label
    assert_equal "https://noname.example", links.last.label # falls back to url
  end

  test "local_date reads the label's month/day" do
    assert_equal Date.new(20.days.from_now.year, 9, 14), segments(:lisbon_flight).local_date
  end

  test "local_date falls back to the stored instant, then nil" do
    hotel = segments(:lisbon_hotel)
    assert_nil hotel.local_date
    hotel.update!(starts_at: Time.utc(2026, 9, 14, 15))
    assert_equal Date.new(2026, 9, 14), hotel.reload.local_date
  end
end
