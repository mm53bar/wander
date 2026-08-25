require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  test "configured? needs a base url and model" do
    assert_not LlmClient.new(base_url: nil, model: nil).configured?
    assert_not LlmClient.new(base_url: "http://x/v1", model: nil).configured?
    assert LlmClient.new(base_url: "http://x/v1", model: "m").configured?
  end

  test "complete_json returns nil when not configured (no network)" do
    assert_nil LlmClient.new(base_url: nil, model: nil).complete_json(system: "s", user: "u")
  end
end
