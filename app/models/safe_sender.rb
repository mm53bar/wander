# A travel provider's sender address or domain that marks a message as a
# booking. Managed on the Settings page. Matched anywhere in the message —
# header or body — because bookings are usually forwarded to the shared inbox,
# so the provider's address lives in the body, not the From header.
class SafeSender < ApplicationRecord
  validates :value, presence: true, uniqueness: { case_sensitive: false }

  before_validation { self.value = value.to_s.strip.downcase.presence }

  scope :active, -> { where(active: true) }
  default_scope { order(:value) }

  # Lowercased match strings for the classifier.
  def self.match_values
    active.pluck(:value)
  end

  # The providers wander ships knowing about, so intake works before anyone
  # touches Settings. Idempotent — safe to re-run from db/seeds.rb.
  DEFAULTS = [
    [ "aircanada", "Air Canada" ], [ "westjet", "WestJet" ], [ "flyflair", "Flair" ],
    [ "porterairlines", "Porter" ], [ "united.com", "United" ], [ "delta.com", "Delta" ],
    [ "aa.com", "American" ], [ "ba.com", "British Airways" ], [ "klm.com", "KLM" ],
    [ "lufthansa", "Lufthansa" ], [ "airfrance", "Air France" ], [ "emirates", "Emirates" ],
    [ "ryanair", "Ryanair" ], [ "easyjet", "easyJet" ], [ "southwest.com", "Southwest" ],
    [ "jetblue", "JetBlue" ],
    [ "viarail", "VIA Rail" ], [ "amtrak", "Amtrak" ], [ "eurostar", "Eurostar" ],
    [ "trainline", "Trainline" ],
    [ "bcferries.com", "BC Ferries" ],
    [ "marriott", "Marriott" ], [ "hilton", "Hilton" ], [ "hyatt", "Hyatt" ],
    [ "ihg.com", "IHG" ], [ "accor.com", "Accor" ], [ "booking.com", "Booking.com" ],
    [ "expedia", "Expedia" ], [ "expediamail.com", "Expedia" ], [ "hotels.com", "Hotels.com" ],
    [ "airbnb.com", "Airbnb" ], [ "vrbo.com", "Vrbo" ], [ "agoda", "Agoda" ],
    [ "hostelworld", "Hostelworld" ],
    [ "enterprise.com", "Enterprise" ], [ "hertz", "Hertz" ], [ "avis.com", "Avis" ],
    [ "budget.com", "Budget" ], [ "turo.com", "Turo" ],
    [ "tripit.com", "TripIt" ], [ "kayak.com", "Kayak" ], [ "priceline", "Priceline" ],
    [ "camis.com", "BC Parks / camis" ], [ "reserveamerica", "ReserveAmerica" ],
    [ "recreation.gov", "Recreation.gov" ], [ "parkscanada", "Parks Canada" ],
    [ "parkbridge.com", "Parkbridge" ]
  ].freeze

  def self.seed_defaults!
    DEFAULTS.each { |value, name| find_or_create_by!(value: value) { |s| s.name = name } }
  end
end
