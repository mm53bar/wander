require "test_helper"

class BookingParserTest < ActiveSupport::TestCase
  class FakeLlm
    def initialize(data) = @data = data
    def configured? = true
    def complete_json(**) = @data
  end

  def parse(data)
    BookingParser.new(raw_emails(:lisbon_confirmation), trips(:lisbon), client: FakeLlm.new(data)).segment_attrs
  end

  test "maps the LLM JSON to segment attributes" do
    attrs = parse(
      "kind" => "campsite", "summary" => "Rathtrevor Beach", "starts_at" => "2026-09-08T00:00:00",
      "ends_at" => "2026-09-10T00:00:00", "starts_at_label" => "Arriving Sep 8",
      "location" => "Rathtrevor Beach Provincial Park", "confirmation" => "BCIN27-11143815B1",
      "links" => [ { "label" => "Details", "url" => "https://example.com" }, { "url" => "" } ]
    )
    assert_equal "campsite", attrs[:kind]
    assert_equal "BCIN27-11143815B1", attrs[:confirmation]
    assert_equal 1, attrs[:links].size # blank-url link dropped
    assert_equal "Details", attrs[:links].first["label"]
  end

  test "falls back sensibly on sparse data" do
    attrs = parse("summary" => nil)
    assert_equal "note", attrs[:kind]
    assert_equal raw_emails(:lisbon_confirmation).subject, attrs[:summary]
  end

  test "returns nil when the response is not a JSON object" do
    assert_nil parse(nil)
  end

  test "available? reflects the client" do
    assert BookingParser.new(raw_emails(:lisbon_confirmation), trips(:lisbon), client: FakeLlm.new({})).available?
  end
end
