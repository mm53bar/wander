require "test_helper"

class QrCodesControllerTest < ActionDispatch::IntegrationTest
  test "create attaches a QR code, replacing any existing one" do
    post segment_qr_code_path(segments(:lisbon_hotel)),
      params: { qr_code: { image_data: "aGVsbG8=" } }
    assert_equal "aGVsbG8=", segments(:lisbon_hotel).reload.qr_code.image_data
  end

  test "destroy removes the QR code" do
    assert_difference -> { QrCode.count }, -1 do
      delete segment_qr_code_path(segments(:lisbon_flight))
    end
  end
end
