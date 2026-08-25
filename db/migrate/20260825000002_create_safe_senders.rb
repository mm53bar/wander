class CreateSafeSenders < ActiveRecord::Migration[8.1]
  def change
    create_table :safe_senders do |t|
      # An email address or domain fragment (e.g. "aircanada.ca" or
      # "no-reply@bcferries.com"), matched case-insensitively anywhere in a
      # message — header OR body, since bookings are usually forwarded and the
      # real sender is in the body.
      t.string  :value, null: false
      t.string  :name              # friendly label, e.g. "Air Canada"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :safe_senders, :value, unique: true
  end
end
