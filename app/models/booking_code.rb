require "net/http"
require "resolv"
require "ipaddr"

# Finds the scannable codes in a booking email (a parkade QR, a ferry barcode, a
# campsite pass) and carries them to the segments the email becomes.
#
# Bookings deliver them two ways, both only in the HTML or MIME structure, never
# the plain text intake reads:
#   * an image part inside the message, referenced by cid: (campsite passes)
#   * an <img> loaded from the provider's site (parkade QR, ferry barcode)
# Either is recognised by "qr" or "barcode" in its URL, filename or Content-ID.
# Links (<a>) are ignored: "e-ticket" links on airline itineraries are web pages.
#
# Remote images are downloaded at capture, while the provider still serves them,
# and only from public HTTPS hosts — the URL comes from an email.
class BookingCode
  PATTERN = /qr|barcode/i
  MAX_BYTES = 512.kilobytes
  MAX_CODES = 6

  def self.extract(mail, fetcher: method(:fetch)) = new(mail, fetcher).extract

  # Codes as stored on InboundEmail#booking_codes:
  #   { "source" => URL or "cid:<id>", "content_type" => "image/png", "data" => base64 }
  def initialize(mail, fetcher)
    @mail = mail
    @fetcher = fetcher
  end

  def extract
    (inline_codes + remote_codes).uniq { |c| c["data"] }.first(MAX_CODES)
  rescue StandardError => e
    Rails.logger.warn("BookingCode: extraction failed: #{e.class}: #{e.message}")
    []
  end

  # Which codes go on which of an email's segments. A code naming a segment's
  # confirmation goes to that segment. A lone code goes to every segment, since
  # one code for a there-and-back booking opens either leg. Several codes that
  # name no confirmation are left off: wander can't tell which leg each is for.
  def self.assign(codes, segments)
    codes = Array(codes)
    segments.each_with_object({}) do |segment, plan|
      conf = segment.confirmation.to_s.strip
      named = codes.find { |c| conf.length >= 4 && c["source"].to_s.include?(conf) }
      code = named || (codes.one? ? codes.first : nil)
      plan[segment] = code if code
    end
  end

  def self.fetch(url)
    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTPS) && public_host?(uri.host)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.get(uri.request_uri)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    type = response.content_type.to_s
    body = response.body.to_s
    return nil unless type.start_with?("image/") && body.bytesize.between?(64, MAX_BYTES)
    [ type, body ]
  rescue StandardError => e
    Rails.logger.warn("BookingCode: could not fetch #{url}: #{e.class}: #{e.message}")
    nil
  end

  def self.public_host?(host)
    addresses = Resolv.getaddresses(host.to_s)
    addresses.any? && addresses.none? do |a|
      ip = IPAddr.new(a)
      ip.private? || ip.loopback? || ip.link_local? || ip.to_s == "0.0.0.0"
    end
  rescue IPAddr::InvalidAddressError
    false
  end

  private

  def inline_codes
    @mail.all_parts.filter_map do |part|
      next unless part.mime_type.to_s.start_with?("image/")
      cid = part.content_id.to_s.delete("<>")
      next unless "#{part.filename} #{cid}".match?(PATTERN)
      body = part.decoded.to_s
      next unless body.bytesize.between?(64, MAX_BYTES)
      code("cid:#{cid.presence || part.filename}", part.mime_type, body)
    end
  end

  def remote_codes
    image_sources.filter_map do |src|
      next unless src.start_with?("https://") && src.match?(PATTERN)
      type, body = @fetcher.call(src)
      code(src, type, body) if body
    end
  end

  def image_sources
    part = @mail.multipart? ? @mail.html_part : (@mail if @mail.mime_type == "text/html")
    html = part&.decoded.to_s
    Nokogiri::HTML(html).css("img[src]").map { |img| img["src"].to_s.strip }.uniq
  end

  def code(source, content_type, bytes)
    { "source" => source, "content_type" => content_type, "data" => Base64.strict_encode64(bytes) }
  end
end
