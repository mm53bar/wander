class AddTriageAttemptsToInboundEmails < ActiveRecord::Migration[8.1]
  def change
    # Failed triage attempts, so a transient LLM outage is retried rather than
    # mistaken for a booking nobody can read.
    add_column :inbound_emails, :triage_attempts, :integer, null: false, default: 0
  end
end
