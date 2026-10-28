require "test_helper"

class QrCodeTest < ActiveSupport::TestCase
  test "data_uri types the image from its bytes" do
    jpeg = Base64.strict_encode64("\xFF\xD8\xFF\xE0".b + "x" * 20)
    png = Base64.strict_encode64("\x89PNG\r\n\x1a\n".b + "x" * 20)
    assert QrCode.new(image_data: jpeg).data_uri.start_with?("data:image/jpeg;base64,")
    assert QrCode.new(image_data: png).data_uri.start_with?("data:image/png;base64,")
  end
end
