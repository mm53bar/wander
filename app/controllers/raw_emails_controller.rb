class RawEmailsController < ApplicationController
  before_action :set_trip

  def index
    render json: @trip.raw_emails.order(:received_at)
  end

  # Ingest a source email (booking confirmation, itinerary, etc.) against a
  # trip. Kept verbatim for reference and auto-archived once the trip is over.
  def create
    email = @trip.raw_emails.new(email_params)
    if email.save
      respond_to do |format|
        format.html { redirect_to @trip, notice: "Email saved." }
        format.json { head :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @trip, alert: email.errors.full_messages.to_sentence }
        format.json { render json: { errors: email.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def email_params
    params.require(:raw_email).permit(:from_address, :subject, :body, :received_at)
  end
end
