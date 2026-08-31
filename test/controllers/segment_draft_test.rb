require "test_helper"

class SegmentDraftTest < ActionDispatch::IntegrationTest
  class FakeConfigured
    def configured? = true
    def complete_json(**)
      { "segments" => [
        { "kind" => "campsite", "summary" => "Rathtrevor Beach",
          "starts_at_local" => "2026-09-08T13:00", "starts_time_zone" => "America/Vancouver",
          "confirmation" => "BCIN27-1" },
        { "kind" => "ferry", "summary" => "Comox to Powell River",
          "starts_at_local" => "2026-09-10T09:55", "starts_time_zone" => "America/Vancouver",
          "confirmation" => "B266864753" }
      ] }
    end
  end

  # Swap LlmClient.from_env for a fake, then restore — no mock framework needed.
  def with_llm(fake)
    original = LlmClient.method(:from_env)
    LlmClient.define_singleton_method(:from_env) { fake }
    yield
  ensure
    LlmClient.define_singleton_method(:from_env, original)
  end

  class FakeEmpty
    def configured? = true
    def complete_json(**) = { "segments" => [] }
  end

  test "redirects when the LLM finds no segments at all" do
    with_llm(FakeEmpty.new) do
      get draft_segment_path(raw_emails(:lisbon_confirmation))
    end
    assert_redirected_to trips(:lisbon)
  end

  test "redirects with an alert when the LLM isn't configured" do
    get draft_segment_path(raw_emails(:lisbon_confirmation))
    assert_redirected_to trips(:lisbon)
    assert_match(/isn't configured/, flash[:alert])
  end

  test "renders a prefilled segment form for review when configured" do
    with_llm(FakeConfigured.new) do
      get draft_segment_path(raw_emails(:lisbon_confirmation))
    end
    assert_response :success
    assert_select "h1", text: /Review 2 drafted segments/
    assert_select "input[name=?][value=?]", "segment[summary]", "Rathtrevor Beach"
    assert_select "input[name=?][value=?]", "segment[summary]", "Comox to Powell River"
  end
end
