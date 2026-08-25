require "test_helper"

class SafeSenderTest < ActiveSupport::TestCase
  test "normalizes value to stripped lowercase" do
    s = SafeSender.create!(value: "  AirCanada.CA ")
    assert_equal "aircanada.ca", s.value
  end

  test "value is unique" do
    assert_not SafeSender.new(value: "BCFerries.com").valid?  # dup of fixture (case-insensitive)
  end

  test "match_values returns only active values" do
    assert_includes SafeSender.match_values, "bcferries.com"
    assert_not_includes SafeSender.match_values, "disabled-air.example"
  end

  test "seed_defaults! is idempotent" do
    SafeSender.seed_defaults!
    assert_no_difference -> { SafeSender.count } do
      SafeSender.seed_defaults!
    end
    assert SafeSender.exists?(value: "aircanada")
  end
end
