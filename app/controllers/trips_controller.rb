class TripsController < ApplicationController
  before_action :set_trip, only: %i[show edit update destroy archive unarchive]

  def index
    # Discard source emails for trips that ended a while ago (belt-and-braces;
    # the daily job normally does this).
    RawEmail.archive_past!

    @upcoming = Trip.upcoming.includes(segments: :qr_code, raw_emails: {})
    @past = Trip.past.includes(segments: :qr_code)
    @archived = Trip.archived.includes(segments: :qr_code)

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def new
    @trip = Trip.new
  end

  def edit; end

  def create
    @trip = Trip.new(trip_params)
    if @trip.save
      respond_to do |format|
        format.html { redirect_to @trip, notice: "Trip created." }
        format.json { render :show, status: :created, location: @trip }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @trip.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @trip.update(trip_params)
      respond_to do |format|
        format.html { redirect_to @trip, notice: "Trip updated." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @trip.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @trip.destroy
    respond_to do |format|
      format.html { redirect_to root_path, notice: "Trip deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def archive
    @trip.archive!
    redirect_to @trip, notice: "Trip archived."
  end

  def unarchive
    @trip.unarchive!
    redirect_to @trip, notice: "Trip unarchived."
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def trip_params
    params.require(:trip).permit(
      :name, :destination, :start_date, :end_date, :travellers, :booking_ref, :booked_via, :notes
    )
  end
end
