require "test_helper"

class RawEmailsControllerTest < ActionDispatch::IntegrationTest
  test "json create ingests an email against a trip" do
    assert_difference -> { trips(:lisbon).raw_emails.count }, 1 do
      post trip_raw_emails_path(trips(:lisbon), format: :json),
        params: { raw_email: { subject: "Booked", body: "See you there" } }.to_json,
        headers: { "Content-Type" => "application/json" }
    end
    assert_response :created
  end
end
