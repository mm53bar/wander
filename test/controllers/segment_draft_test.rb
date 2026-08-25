require "test_helper"

class SegmentDraftTest < ActionDispatch::IntegrationTest
  class FakeConfigured
    def configured? = true
    def complete_json(**) = { "kind" => "campsite", "summary" => "Rathtrevor Beach",
      "starts_at" => "2026-09-08T00:00:00", "confirmation" => "BCIN27-1" }
  end

  # Swap LlmClient.from_env for a fake, then restore — no mock framework needed.
  def with_llm(fake)
    original = LlmClient.method(:from_env)
    LlmClient.define_singleton_method(:from_env) { fake }
    yield
  ensure
    LlmClient.define_singleton_method(:from_env, original)
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
    assert_select "h1", text: /Review drafted segment/
    assert_select "input[name=?][value=?]", "segment[summary]", "Rathtrevor Beach"
  end
end
