class InboundEmailsController < ApplicationController
  def index
    # Belt-and-braces: clear anything already recorded (confirmation match).
    InboundEmail.received.each do |email|
      email.resolve_as_duplicate!(email.duplicate_trip) if email.duplicate_trip
    end

    @trips = Trip.fileable
    @inbound_emails = InboundEmail.received.to_a
    # Fallback suggestion for items with no LLM proposal (e.g. captured before
    # triage, or LLM unavailable).
    @suggestions = @inbound_emails.reject(&:proposal?).index_with(&:suggested_trip)
    @auto_filed = InboundEmail.where(auto_filed: true, status: "filed").order(updated_at: :desc).limit(10).includes(:trip)
  end

  # Materialize a triage proposal: create the segment on the chosen/proposed trip
  # (or a new trip), optionally extending the trip's dates.
  def accept
    inbound = InboundEmail.find(params[:id])
    override = Trip.find_by(id: params[:trip_id]) if params[:trip_id].present?
    segment = inbound.accept!(trip: override, extend_dates: params[:extend_dates] == "1")
    redirect_to segment.trip, notice: "Added “#{segment.summary}” to #{segment.trip.name}."
  rescue StandardError => e
    redirect_to inbound_emails_path, alert: "Couldn't add that: #{e.message}"
  end

  # Legacy path: file as a source email only (no segment).
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

  def undo
    inbound = InboundEmail.find(params[:id])
    inbound.undo_auto_file!
    redirect_to inbound_emails_path, notice: "Undone — back in the inbox."
  end

  def destroy
    InboundEmail.find(params[:id]).destroy
    redirect_to inbound_emails_path, notice: "Deleted.", status: :see_other
  end
end
