require "test_helper"

class SegmentTimeTest < ActiveSupport::TestCase
  def resolve(**args) = SegmentTime.resolve(**args)

  test "a zone abbreviation in the booking's own wording wins" do
    at = resolve(local: "2026-09-08T13:00", label: "Sep 8, 1:00 PM PDT")
    assert_equal "2026-09-08T13:00:00-07:00", at.iso8601
  end

  test "falls back to an IANA zone from the model, with DST applied per date" do
    summer = resolve(local: "2026-09-08T13:00", label: "Check In: 1:00 p.m.", zone: "America/Vancouver")
    winter = resolve(local: "2026-01-08T13:00", label: "Check In: 1:00 p.m.", zone: "America/Vancouver")
    assert_equal "-07:00", summer.iso8601.last(6)
    assert_equal "-08:00", winter.iso8601.last(6)
  end

  test "falls back to the location table when there's no label zone or IANA zone" do
    at = resolve(local: "2026-09-08T13:00", location: "Rathtrevor Beach Provincial Park, Parksville, BC")
    assert_equal "2026-09-08T13:00:00-07:00", at.iso8601
  end

  test "an offset the model supplied anyway is discarded, not trusted" do
    at = resolve(local: "2026-09-08T13:00-04:00", zone: "America/Vancouver")
    assert_equal "2026-09-08T13:00:00-07:00", at.iso8601
  end

  test "undated rather than guessed when nothing resolves" do
    assert_nil resolve(local: "2026-09-08T13:00", label: "1:00 PM", location: "Somewhere unlisted")
    assert_nil resolve(local: "2026-09-08T13:00", zone: "Mars/Olympus")
    assert_nil resolve(local: "not a time", zone: "America/Vancouver")
    assert_nil resolve(local: nil, zone: "America/Vancouver")
  end

  test "ambiguous abbreviations are not treated as offsets" do
    # CST is -06:00 in Winnipeg and +08:00 in Shanghai — it must fall through.
    assert_nil resolve(local: "2026-09-08T13:00", label: "1:00 PM CST")
    assert_equal "-07:00",
                 resolve(local: "2026-09-08T13:00", label: "1:00 PM CST", zone: "America/Vancouver").iso8601.last(6)
  end

  test "from_llm resolves both ends and lets the end carry its own zone" do
    times = SegmentTime.from_llm(
      "starts_at_local" => "2026-10-20T16:25", "starts_time_zone" => "America/Edmonton",
      "ends_at_local" => "2026-10-20T17:04", "ends_time_zone" => "America/Vancouver"
    )
    assert_equal "-06:00", times[:starts_at].iso8601.last(6)
    assert_equal "-07:00", times[:ends_at].iso8601.last(6)
  end

  test "from_llm falls back to the start's zone for the end" do
    times = SegmentTime.from_llm(
      "starts_at_local" => "2026-09-08T13:00", "starts_time_zone" => "America/Vancouver",
      "ends_at_local" => "2026-09-10T11:00"
    )
    assert_equal "-07:00", times[:ends_at].iso8601.last(6)
  end
end
