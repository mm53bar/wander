require "net/http"
require "json"
require "uri"

# Thin read-only client for the Bichon email archiver's HTTP API. Bichon syncs
# the shared casey@ mailbox from Fastmail and exposes full-text search; wander
# reads through it rather than holding IMAP credentials or touching the live
# mailbox (Bichon is read-only against the provider). See the homelab `bichon`
# skill for the API.
#
# Config (env): BICHON_URL, BICHON_API_TOKEN, BICHON_ACCOUNT_ID (casey@).
class BichonClient
  # One message envelope. Bichon's `text` field already carries the body, so a
  # separate content fetch isn't needed for classification or capture.
  # The envelope `text` is a short preview; `id` is Bichon's numeric id, used to
  # fetch the full body via #content.
  Message = Data.define(:id, :message_id, :from, :subject, :preview, :received_at) do
    def self.from_envelope(env)
      date_ms = env["date"] || env["internal_date"]
      new(
        id: env["id"],
        message_id: env["message_id"].presence || "bichon-#{env["id"]}",
        from: env["from"], subject: env["subject"], preview: env["text"].to_s,
        received_at: date_ms ? Time.at(date_ms.to_i / 1000) : Time.current
      )
    end
  end

  def self.from_env
    new(base_url: ENV["BICHON_URL"], token: ENV["BICHON_API_TOKEN"], account_id: ENV["BICHON_ACCOUNT_ID"])
  end

  def initialize(base_url:, token:, account_id:)
    @base_url = base_url.to_s.chomp("/")
    @token = token
    @account_id = account_id
  end

  def configured?
    @base_url.present? && @token.present? && @account_id.present?
  end

  # Messages for the configured account received since `since` (a Time),
  # newest first, following pagination up to `max_pages`.
  def messages_since(since, page_size: 25, max_pages: 20)
    messages = []
    page = 1
    loop do
      data = search(since_ms: (since.to_f * 1000).to_i, page: page, page_size: page_size)
      items = data["items"] || []
      messages.concat(items.map { |env| Message.from_envelope(env) })
      break if page >= (data["total_pages"] || 1) || page >= max_pages || items.empty?
      page += 1
    end
    messages
  end

  # Full plaintext body for a message (the envelope only carries a preview).
  # Falls back to HTML with tags stripped, then the preview.
  def content(id, fallback: "")
    uri = URI("#{@base_url}/api/v1/message-content/#{@account_id}/#{id}")
    req = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@token}")
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30) { |h| h.request(req) }
    return fallback unless res.code.to_i.between?(200, 299)
    data = JSON.parse(res.body)
    data["text"].presence || strip_html(data["html"]).presence || fallback
  rescue StandardError
    fallback
  end

  private

  def strip_html(html)
    return nil if html.blank?
    ActionView::Base.full_sanitizer.sanitize(html).to_s.squish
  end

  def search(since_ms:, page:, page_size:)
    uri = URI("#{@base_url}/api/v1/search-messages")
    req = Net::HTTP::Post.new(uri, "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json")
    req.body = {
      filter: { account_ids: [ @account_id.to_i ], since: since_ms },
      page: page, page_size: page_size, desc: true
    }.to_json
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 30) { |h| h.request(req) }
    raise "Bichon search failed: #{res.code}" unless res.code.to_i.between?(200, 299)
    JSON.parse(res.body)
  end
end
