class QrCode < ApplicationRecord
  belongs_to :segment

  validates :image_data, presence: true

  SIGNATURES = { "/9j/" => "image/jpeg", "iVBORw0KGgo" => "image/png", "R0lGOD" => "image/gif" }.freeze

  # Rendered inline in an <img src>. The stored value is raw base64 image bytes,
  # typed from their signature: providers serve JPEG as often as PNG.
  def data_uri
    type = SIGNATURES.find { |prefix, _| image_data.to_s.start_with?(prefix) }&.last || "image/png"
    "data:#{type};base64,#{image_data}"
  end
end
