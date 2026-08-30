class CreateAllowedSenders < ActiveRecord::Migration[8.1]
  def change
    create_table :allowed_senders do |t|
      t.string  :address, null: false
      t.string  :note
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :allowed_senders, :address, unique: true
  end
end
