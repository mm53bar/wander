# An address wander will send a manual-handling notice back to. Managed on the
# Settings page, and deliberately NOT the same list as SafeSender: that one is
# travel providers, matched anywhere in a message including a forwarded body, so
# reusing it here would let a vendor address quoted inside an email authorise a
# reply to that vendor. This list is matched against the envelope From only.
#
# It ships empty — the addresses are personal data and the repo is public. An
# empty list means no notices are sent; the Settings page says so.
class AllowedSender < ApplicationRecord
  validates :address, presence: true, uniqueness: { case_sensitive: false }

  before_validation { self.address = address.to_s.strip.downcase.presence }

  scope :active, -> { where(active: true) }
  default_scope { order(:address) }

  # The bare address out of a From header, which may be "Name <addr>" or bare.
  def self.address_in(from)
    Mail::Address.new(from.to_s).address&.downcase
  rescue StandardError
    from.to_s[/[\w.+-]+@[\w.-]+/]&.downcase
  end

  def self.allows?(from)
    address = address_in(from)
    address.present? && active.exists?(address: address)
  end
end
