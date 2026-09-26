require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  class Canned < LlmClient
    def initialize(code) = super(base_url: "http://x/v1", model: "m").tap { @code = code }
    private def post(*) = Struct.new(:code, :body).new(@code, "")
  end

  test "configured? needs a base url and model" do
    assert_not LlmClient.new(base_url: nil, model: nil).configured?
    assert_not LlmClient.new(base_url: "http://x/v1", model: nil).configured?
    assert LlmClient.new(base_url: "http://x/v1", model: "m").configured?
  end

  test "complete_json returns nil when not configured (no network)" do
    assert_nil LlmClient.new(base_url: nil, model: nil).complete_json(system: "s", user: "u")
  end

  test "parse_content reads bare JSON" do
    assert_equal({ "a" => 1 }, LlmClient.parse_content('{"a":1}'))
  end

  test "parse_content strips a Markdown code fence" do
    assert_equal({ "a" => 1 }, LlmClient.parse_content("```json\n{\"a\":1}\n```"))
    assert_equal({ "a" => 1 }, LlmClient.parse_content("  ```\n{\"a\":1}\n```\n"))
  end

  test "parse_content keeps backticks inside a string value" do
    assert_equal({ "a" => "```x```" }, LlmClient.parse_content('{"a":"```x```"}'))
  end

  test "parse_content returns nil for no content and raises on non-JSON" do
    assert_nil LlmClient.parse_content(nil)
    assert_raises(JSON::ParserError) { LlmClient.parse_content("```json\nnope\n```") }
  end

  test "complete_json treats rate limiting and server errors as unavailable" do
    %w[408 429 503].each do |code|
      assert_raises(LlmClient::Unavailable) { Canned.new(code).complete_json(system: "s", user: "u") }
    end
  end

  test "complete_json returns nil for a client error" do
    assert_nil Canned.new("400").complete_json(system: "s", user: "u")
  end
end
