require "test_helper"

class BichonClientTest < ActiveSupport::TestCase
  test "not configured without url/token/account" do
    assert_not BichonClient.new(base_url: nil, token: nil, account_id: nil).configured?
    assert BichonClient.new(base_url: "http://x", token: "t", account_id: "1").configured?
  end

  test "Message.from_envelope maps Bichon fields, including epoch-ms date" do
    msg = BichonClient::Message.from_envelope(
      "message_id" => "<a@b>", "from" => "x@y.com", "subject" => "Hi",
      "text" => "body here", "date" => 1_787_527_187_000
    )
    assert_equal "<a@b>", msg.message_id
    assert_equal "body here", msg.body
    assert_equal Time.at(1_787_527_187), msg.received_at
  end

  test "Message.from_envelope synthesizes an id when message_id is blank" do
    msg = BichonClient::Message.from_envelope("id" => 42, "message_id" => "", "text" => "")
    assert_equal "bichon-42", msg.message_id
  end
end
