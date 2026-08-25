class InboundEmailsController < ApplicationController
  def index
    @inbound_emails = InboundEmail.received
    @trips = Trip.order(start_date: :desc)
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
end
