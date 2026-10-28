require "test_helper"

class SegmentTimeTest < ActiveSupport::TestCase
  def resolve(**args) = SegmentTime.resolve(**args)

  test "a zone abbreviation in the label decides when no zone is known" do
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

  test "a known zone wins over a stale abbreviation in the label" do
    assert_equal "2027-01-03T07:00:00-06:00",
                 resolve(local: "2027-01-03T07:00", label: "Jan 3, 7:00 AM MST", zone: "America/Edmonton").iso8601
    assert_equal "2027-01-03T16:00:00-07:00",
                 resolve(local: "2027-01-03T16:00", label: "Jan 3, 4:00 PM PST", location: "YYJ Victoria").iso8601
    assert_equal "2026-10-03T16:00:00-07:00",
                 resolve(local: "2026-10-03T16:00", label: "Check-In Time 4:00 p.m. (PST)", location: "Victoria, BC").iso8601
  end

  test "a known zone wins over an abbreviation it has never used" do
    at = resolve(local: "2027-01-03T07:00", label: "Jan 3, 7:00 AM EST", zone: "America/Vancouver")
    assert_equal "2027-01-03T07:00:00-07:00", at.iso8601
  end

  test "an old abbreviation with no zone to defer to is still read as its offset" do
    assert_equal "-08:00", resolve(local: "2027-01-03T16:00", label: "Jan 3, 4:00 PM PST").iso8601.last(6)
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

  def flight(start_zone, end_zone, summary: "WS 503 from Edmonton (YEG) to Victoria (YYJ)")
    { "kind" => "flight", "summary" => summary, "location" => "Victoria, BC",
      "starts_at_local" => "2027-01-03T07:00", "starts_time_zone" => start_zone,
      "ends_at_local" => "2027-01-03T07:55", "ends_time_zone" => end_zone }
  end

  test "zone_check passes a journey whose zones match the places its summary names" do
    assert_nil SegmentTime.from_llm(flight("America/Edmonton", "America/Vancouver"))[:zone_check]
  end

  test "zone_check flags a journey end the model put in the departure's zone" do
    check = SegmentTime.from_llm(flight("America/Edmonton", "America/Edmonton"))[:zone_check]
    assert_match(/\Aend resolved to UTC-06:00 but America\/Vancouver is UTC-07:00\z/, check)
  end

  test "zone_check judges a journey by its summary, not a location naming one end" do
    assert_nil SegmentTime.from_llm(flight("America/Edmonton", "America/Vancouver").merge("location" => "Victoria, BC"))[:zone_check]
  end

  test "zone_check skips a journey whose summary names fewer than two places" do
    assert_nil SegmentTime.from_llm(flight("America/Toronto", "America/Toronto", summary: "WestJet flight WS 503"))[:zone_check]
  end

  test "zone_check holds a stay to its location" do
    stay = { "kind" => "hotel", "summary" => "Harbour stay", "location" => "100 Wharf Street, Victoria, BC",
             "starts_at_local" => "2027-07-15T16:00", "starts_time_zone" => "America/Edmonton" }
    assert_match(/\Astart resolved to UTC-06:00 but America\/Vancouver/, SegmentTime.from_llm(stay)[:zone_check])
    assert_nil SegmentTime.from_llm(stay.merge("starts_time_zone" => "America/Vancouver"))[:zone_check]
  end

  test "the location table takes the first place the location names" do
    at = resolve(local: "2027-03-12T18:05", zone: "America/Calgary", location: "Calgary (YYC) to Vancouver (YVR)")
    assert_equal "2027-03-12T18:05:00-06:00", at.iso8601
  end

  test "a bare 'on' in a location is not read as Ontario" do
    assert_empty SegmentTime.places_in("Parking on level 2")
    assert_equal [ "America/Toronto" ], SegmentTime.places_in("Kingston, ON").map { |z| z.tzinfo.identifier }
  end
end
