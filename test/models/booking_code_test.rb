require "test_helper"

class BookingCodeTest < ActiveSupport::TestCase
  PNG = "\\x89PNG\\r\\n\\x1a\\n".b + ("x" * 100).b

  def booking_mail(html, inline: nil)
    mail = Mail.new
    mail.text_part = Mail::Part.new(body: "Your booking is confirmed.")
    mail.html_part = Mail::Part.new(content_type: "text/html; charset=UTF-8", body: html)
    mail.attachments.inline[inline] = { mime_type: "image/png", content: PNG } if inline
    mail
  end

  def segment(confirmation)
    Segment.new(kind: "ferry", summary: "Leg", confirmation: confirmation)
  end

  test "takes an image embedded in the message under a code-like name" do
    codes = BookingCode.extract(booking_mail('<img src="cid:pass">', inline: "barcode.png"), fetcher: ->(_) { flunk "no fetch expected" })
    assert_equal 1, codes.size
    assert_equal "image/png", codes.first["content_type"]
    assert_equal PNG, Base64.strict_decode64(codes.first["data"])
  end

  test "downloads a code-like remote image, and nothing else in the email" do
    html = <<~HTML
      <img src="https://parking.example.com/barcode/QRCodeGen?data=123">
      <img src="https://parking.example.com/logo.png">
      <img src="http://parking.example.com/qr/insecure.png">
      <a href="https://docs.example.com/eticketPrint.html?epk=1">Your e-ticket</a>
    HTML
    fetched = []
    codes = BookingCode.extract(booking_mail(html), fetcher: ->(url) { fetched << url; [ "image/jpeg", PNG ] })
    assert_equal [ "https://parking.example.com/barcode/QRCodeGen?data=123" ], fetched
    assert_equal [ "https://parking.example.com/barcode/QRCodeGen?data=123" ], codes.map { |c| c["source"] }
  end

  test "skips a remote code that can't be downloaded" do
    html = '<img src="https://parking.example.com/barcode/1">'
    assert_empty BookingCode.extract(booking_mail(html), fetcher: ->(_) { nil })
  end

  test "a code naming a segment's confirmation goes to that segment" do
    out, back = segment("B100200300"), segment("B100200399")
    codes = [ { "source" => "https://ferry.example.com/barcode/B100200399" },
              { "source" => "https://ferry.example.com/barcode/B100200300" } ]
    plan = BookingCode.assign(codes, [ out, back ])
    assert_equal "https://ferry.example.com/barcode/B100200300", plan[out]["source"]
    assert_equal "https://ferry.example.com/barcode/B100200399", plan[back]["source"]
  end

  test "a lone code goes on every segment" do
    out, back = segment("RT1234"), segment("RT1234")
    plan = BookingCode.assign([ { "source" => "cid:barcode" } ], [ out, back ])
    assert_equal [ out, back ], plan.keys
  end

  test "several codes that name no confirmation go nowhere" do
    codes = [ { "source" => "cid:barcode-1" }, { "source" => "cid:barcode-2" } ]
    assert_empty BookingCode.assign(codes, [ segment("AAA111"), segment("BBB222") ])
  end

  test "never fetches from a private or loopback address" do
    assert_not BookingCode.public_host?("127.0.0.1")
    assert_not BookingCode.public_host?("192.168.0.10")
    assert_nil BookingCode.fetch("https://10.0.0.5/barcode/1")
  end
end
