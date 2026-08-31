require "test_helper"

class TripTriagerTest < ActiveSupport::TestCase
  class Fake
    attr_reader :user_prompt

    def initialize(data) = @data = data
    def configured? = true
    def complete_json(**kwargs)
      @user_prompt = kwargs[:user]
      @data
    end
  end

  test "maps triage output to a proposal" do
    fake = Fake.new(
      "segments" => [ { "kind" => "ferry", "summary" => "Ferry", "confirmation" => "X", "links" => [ { "label" => "a", "url" => "https://x" } ] } ],
      "assignment" => { "trip_id" => trips(:lisbon).id, "extends_trip" => false, "confidence" => "high", "reason" => "r" }
    )
    p = TripTriager.new(inbound_emails(:pending_flight), client: fake).triage
    assert_equal "ferry", p[:segments].first["kind"]
    assert_equal trips(:lisbon).id, p[:trip_id]
    assert_equal "high", p[:confidence]
    assert_equal 1, p[:segments].first["links"].size
  end

  test "keeps every leg the email describes" do
    fake = Fake.new(
      "segments" => [ { "kind" => "ferry", "confirmation" => "A" }, { "kind" => "ferry", "confirmation" => "B" } ],
      "assignment" => { "trip_id" => trips(:lisbon).id, "confidence" => "high" }
    )
    proposal = TripTriager.new(inbound_emails(:pending_flight), client: fake).triage
    assert_equal %w[A B], proposal[:segments].map { |s| s["confirmation"] }
  end

  test "rejects a trip id that isn't a real trip" do
    fake = Fake.new("segments" => [ { "kind" => "x" } ], "assignment" => { "trip_id" => 999_999, "confidence" => "low" })
    assert_nil TripTriager.new(inbound_emails(:pending_flight), client: fake).triage[:trip_id]
  end

  test "not available without a configured client" do
    unconf = Class.new { def configured? = false }.new
    assert_not TripTriager.new(inbound_emails(:pending_flight), client: unconf).available?
  end

  # The email's dates drive the hint, so build bodies relative to the lisbon
  # fixture's span (20..25 days out) rather than hard-coding calendar dates.
  def email_dated(*days_out)
    inbound_emails(:pending_flight).tap do |e|
      e.body = "Booking dates: #{days_out.map { |d| d.days.from_now.to_date.iso8601 }.join(' to ')}."
    end
  end

  def prompt_for(email)
    fake = Fake.new("segments" => [ { "kind" => "x" } ], "assignment" => { "confidence" => "low" })
    TripTriager.new(email, client: fake).triage
    fake.user_prompt
  end

  test "prompt carries a DATE MATCH naming the trip the dates fall inside" do
    prompt = prompt_for(email_dated(21, 23))
    assert_match(/DATE MATCH: 2 of the email's dates/, prompt)
    assert_match(/trip id=#{trips(:lisbon).id} "Lisbon City Break"/, prompt)
    assert_no_match(/EXTENDS case/, prompt)
  end

  test "prompt says when the match is adjacent rather than inside" do
    prompt = prompt_for(email_dated(27))   # 2 days past lisbon's end
    assert_match(/within #{TripMatcher::LEEWAY_DAYS} days of trip id=#{trips(:lisbon).id}/, prompt)
    assert_match(/just outside it/, prompt)
    assert_match(/EXTENDS case with suggested_end_date/, prompt)
  end

  test "prompt flags a backwards extend when the booking starts before the trip" do
    first = 18.days.from_now.to_date       # 2 days before lisbon starts
    prompt = prompt_for(email_dated(18, 22))
    assert_match(/EXTENDS case with suggested_start_date=#{first}/, prompt)
  end

  test "prompt flags an EXTENDS case when the booking runs past the trip's end" do
    last = 27.days.from_now.to_date
    prompt = prompt_for(email_dated(24, 27))
    assert_match(/trip id=#{trips(:lisbon).id}/, prompt)
    assert_match(/treat it as an EXTENDS case with suggested_end_date=#{last}/, prompt)
  end

  test "no DATE MATCH when the email has no dates in any trip's span" do
    assert_no_match(/DATE MATCH/, prompt_for(email_dated(300)))
    assert_no_match(/DATE MATCH/, prompt_for(inbound_emails(:pending_flight)))
  end

  test "a finished trip never wins the DATE MATCH" do
    assert_equal trips(:kyoto).start_date, 90.days.ago.to_date, "fixture moved"
    assert_no_match(/DATE MATCH/, prompt_for(email_dated(-85)))

    # A booking date inside the finished trip must not outrank the upcoming one.
    prompt = prompt_for(email_dated(-85, 21, 23))
    assert_match(/trip id=#{trips(:lisbon).id}/, prompt)
    assert_no_match(/trip id=#{trips(:kyoto).id}\b/, prompt)
  end
end
