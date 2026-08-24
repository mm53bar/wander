class QrCode < ApplicationRecord
  belongs_to :segment

  validates :image_data, presence: true

  # Rendered inline in an <img src>. The stored value is raw base64 PNG bytes.
  def data_uri
    "data:image/png;base64,#{image_data}"
  end
end
