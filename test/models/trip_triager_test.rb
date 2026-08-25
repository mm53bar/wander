require "test_helper"

class TripTriagerTest < ActiveSupport::TestCase
  class Fake
    def initialize(data) = @data = data
    def configured? = true
    def complete_json(**) = @data
  end

  test "maps triage output to a proposal" do
    fake = Fake.new(
      "segment" => { "kind" => "ferry", "summary" => "Ferry", "confirmation" => "X", "links" => [ { "label" => "a", "url" => "https://x" } ] },
      "assignment" => { "trip_id" => trips(:lisbon).id, "extends_trip" => false, "confidence" => "high", "reason" => "r" }
    )
    p = TripTriager.new(inbound_emails(:pending_flight), client: fake).triage
    assert_equal "ferry", p[:segment]["kind"]
    assert_equal trips(:lisbon).id, p[:trip_id]
    assert_equal "high", p[:confidence]
    assert_equal 1, p[:segment]["links"].size
  end

  test "rejects a trip id that isn't a real trip" do
    fake = Fake.new("segment" => { "kind" => "x" }, "assignment" => { "trip_id" => 999_999, "confidence" => "low" })
    assert_nil TripTriager.new(inbound_emails(:pending_flight), client: fake).triage[:trip_id]
  end

  test "not available without a configured client" do
    unconf = Class.new { def configured? = false }.new
    assert_not TripTriager.new(inbound_emails(:pending_flight), client: unconf).available?
  end
end
