require "net/http"
require "json"
require "uri"

# Minimal client for an OpenAI-compatible chat endpoint. Works with a local or
# cloud Ollama (both expose /v1/chat/completions) and any other OpenAI-compatible
# provider — the model name selects local vs cloud. All config is env, so the
# public repo carries nothing real and an unconfigured deploy just disables the
# LLM features. See docs/adr/20260825-llm-via-openai-compatible-endpoint.md.
class LlmClient
  # The endpoint couldn't be reached or errored server-side. Distinguished from a
  # nil return (it answered, the answer was unusable) because only this one is
  # worth retrying — and only the other one is worth telling a human about.
  class Unavailable < StandardError; end

  TRANSIENT = [ Net::OpenTimeout, Net::ReadTimeout, IOError, SystemCallError, SocketError ].freeze

  def self.from_env
    new(base_url: ENV["LLM_BASE_URL"], model: ENV["LLM_MODEL"], api_key: ENV["LLM_API_KEY"])
  end

  def initialize(base_url:, model:, api_key: nil)
    @base_url = base_url.to_s.chomp("/")
    @model = model
    @api_key = api_key
  end

  def configured?
    @base_url.present? && @model.present?
  end

  # Returns the parsed JSON object from a json-mode completion, or nil on any
  # failure (not configured, HTTP error, unparseable) — callers degrade to a
  # manual path rather than raising.
  def complete_json(system:, user:, timeout: 45)
    return nil unless configured?

    uri = URI("#{@base_url}/chat/completions")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req["Authorization"] = "Bearer #{@api_key}" if @api_key.present?
    req.body = {
      model: @model, temperature: 0, stream: false,
      response_format: { type: "json_object" },
      messages: [ { role: "system", content: system }, { role: "user", content: user } ]
    }.to_json

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                          open_timeout: 10, read_timeout: timeout) { |h| h.request(req) }
    raise Unavailable, "HTTP #{res.code}" if res.code.to_i >= 500
    return nil unless res.code.to_i.between?(200, 299)

    content = JSON.parse(res.body).dig("choices", 0, "message", "content")
    content && JSON.parse(content)
  rescue *TRANSIENT => e
    Rails.logger.warn("LlmClient unavailable: #{e.class}: #{e.message}")
    raise Unavailable, "#{e.class}: #{e.message}"
  rescue Unavailable
    raise
  rescue StandardError => e
    Rails.logger.error("LlmClient: #{e.class}: #{e.message}")
    nil
  end
end
