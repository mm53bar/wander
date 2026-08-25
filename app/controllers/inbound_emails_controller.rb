class InboundEmailsController < ApplicationController
  def index
    # Auto-resolve anything already recorded (a segment's confirmation number
    # appears in the email) so re-captured/forwarded copies clear themselves.
    @auto_resolved = 0
    InboundEmail.received.each do |email|
      if (trip = email.duplicate_trip)
        email.resolve_as_duplicate!(trip)
        @auto_resolved += 1
      end
    end

    @trips = Trip.fileable
    # For each remaining email, the best-guess trip to default the picker to.
    @inbound_emails = InboundEmail.received.to_a
    @suggestions = @inbound_emails.index_with(&:suggested_trip)
  end

  # File this captured email onto a trip: it becomes one of that trip's source
  # emails and leaves the inbox.
  def file
    inbound = InboundEmail.find(params[:id])
    trip = Trip.find(params[:trip_id])
    inbound.file_to!(trip)
    redirect_to inbound_emails_path, notice: "Filed to #{trip.name}."
  end

  def ignore
    InboundEmail.find(params[:id]).ignore!
    redirect_to inbound_emails_path, notice: "Dismissed."
  end

  def destroy
    InboundEmail.find(params[:id]).destroy
    redirect_to inbound_emails_path, notice: "Deleted.", status: :see_other
  end
end
