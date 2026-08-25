require "test_helper"

class InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  test "index lists received inbound emails" do
    get inbound_emails_path
    assert_response :success
    assert_select "h1", text: /Travel inbox/
  end

  test "file attaches the email to a trip and removes it from the inbox" do
    inbound = inbound_emails(:pending_flight)
    assert_difference -> { trips(:lisbon).raw_emails.count }, 1 do
      post file_inbound_email_path(inbound), params: { trip_id: trips(:lisbon).id }
    end
    assert_equal "filed", inbound.reload.status
    assert_redirected_to inbound_emails_path
  end

  test "ignore dismisses the email" do
    inbound = inbound_emails(:pending_hotel)
    post ignore_inbound_email_path(inbound)
    assert_equal "ignored", inbound.reload.status
  end
end
