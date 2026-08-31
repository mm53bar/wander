require "test_helper"

class BookingParserTest < ActiveSupport::TestCase
  class FakeLlm
    def initialize(data) = @data = data
    def configured? = true
    def complete_json(**) = @data
  end

  def parse_all(payload)
    BookingParser.new(raw_emails(:lisbon_confirmation), trips(:lisbon), client: FakeLlm.new(payload)).segments_attrs
  end

  # Most cases describe a single segment; wrap it in the list shape.
  def parse(data)
    parse_all(data.is_a?(Hash) ? { "segments" => [ data ] } : data)&.first
  end

  test "maps the LLM JSON to segment attributes" do
    attrs = parse(
      "kind" => "campsite", "summary" => "Rathtrevor Beach",
      "starts_at_local" => "2026-09-08T13:00", "starts_time_zone" => "America/Vancouver",
      "ends_at_local" => "2026-09-10T11:00", "starts_at_label" => "Arriving Sep 8",
      "location" => "Rathtrevor Beach Provincial Park", "confirmation" => "BCIN27-11143815B1",
      "links" => [ { "label" => "Details", "url" => "https://example.com" }, { "url" => "" } ]
    )
    assert_equal "campsite", attrs[:kind]
    assert_equal "BCIN27-11143815B1", attrs[:confirmation]
    assert_equal 1, attrs[:links].size # blank-url link dropped
    assert_equal "Details", attrs[:links].first["label"]
    assert_equal "2026-09-08T13:00:00-07:00", attrs[:starts_at].iso8601
    assert_equal "2026-09-10T11:00:00-07:00", attrs[:ends_at].iso8601
  end

  test "leaves the segment undated rather than guessing an unresolvable zone" do
    attrs = parse("kind" => "campsite", "starts_at_local" => "2026-09-08T13:00", "location" => "Somewhere unlisted")
    assert_nil attrs[:starts_at]
  end

  test "falls back sensibly on sparse data" do
    attrs = parse("summary" => nil)
    assert_equal "note", attrs[:kind]
    assert_equal raw_emails(:lisbon_confirmation).subject, attrs[:summary]
  end

  test "returns nil when the response is not a JSON object" do
    assert_nil parse(nil)
  end

  test "extracts every leg the email describes" do
    attrs = parse_all("segments" => [
      { "kind" => "ferry", "confirmation" => "B266864753" },
      { "kind" => "ferry", "confirmation" => "B266864782" }
    ])
    assert_equal %w[B266864753 B266864782], attrs.map { |a| a[:confirmation] }
  end

  test "returns nil when the response carries no segments" do
    assert_nil parse_all("segments" => [])
  end

  test "available? reflects the client" do
    assert BookingParser.new(raw_emails(:lisbon_confirmation), trips(:lisbon), client: FakeLlm.new({})).available?
  end
end
