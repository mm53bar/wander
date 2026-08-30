class AddThreadingToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    change_table :inbound_emails, bulk: true do |t|
      t.text     :references            # original References header, for threading a reply
      t.datetime :notified_at           # a manual-handling notice was sent (once only)
    end
  end
end
