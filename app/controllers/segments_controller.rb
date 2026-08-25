class SegmentsController < ApplicationController
  def new
    @trip = Trip.find(params[:trip_id])
    @segment = @trip.segments.new
  end

  def create
    @trip = Trip.find(params[:trip_id])
    @segment = @trip.segments.new(segment_params)
    if @segment.save
      respond_to do |format|
        format.html { redirect_to @trip, notice: "Segment added." }
        format.json { render :show, status: :created, location: @segment }
      end
    else
      respond_to do |format|
        format.html { redirect_to @trip, alert: @segment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @segment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @segment = Segment.find(params[:id])
    @trip = @segment.trip
  end

  def update
    @segment = Segment.find(params[:id])
    if @segment.update(segment_params)
      respond_to do |format|
        format.html { redirect_to @segment.trip, notice: "Segment updated." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { redirect_to @segment.trip, alert: @segment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @segment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @segment = Segment.find(params[:id])
    trip = @segment.trip
    @segment.destroy
    respond_to do |format|
      format.html { redirect_to trip, notice: "Segment removed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  # Repoint a segment to another trip.
  def move
    @segment = Segment.find(params[:id])
    @trips = Trip.unarchived.where.not(id: @segment.trip_id).order(start_date: :desc)
  end

  def relocate
    @segment = Segment.find(params[:id])
    if params[:target] == "new"
      trip = @segment.split_into_new_trip!(name: params[:new_name])
      redirect_to edit_trip_path(trip), notice: "Split into a new trip — set its details."
    else
      trip = Trip.find(params[:trip_id])
      @segment.move_to(trip)
      redirect_to trip, notice: "Moved to #{trip.name}."
    end
  end

  def split
    @segment = Segment.find(params[:id])
    trip = @segment.split_into_new_trip!
    redirect_to edit_trip_path(trip), notice: "Split into a new trip — set its details."
  end

  # Propose a segment from a stored source email (LLM), rendered in the segment
  # form for review before saving. Degrades to manual entry if unavailable.
  def draft_from_email
    email = RawEmail.find(params[:id])
    @trip = email.trip
    parser = BookingParser.new(email, @trip)
    unless parser.available?
      redirect_to(@trip, alert: "AI drafting isn't configured.") and return
    end

    attrs = parser.segment_attrs
    if attrs
      @segment = @trip.segments.new(attrs)
      @drafted = true
      render "segments/new"
    else
      redirect_to @trip, alert: "Couldn't draft a segment from that email — add it manually."
    end
  end

  private

  def segment_params
    permitted = params.require(:segment).permit(
      :trip_id, :kind, :emoji, :summary, :starts_at, :ends_at, :starts_at_label, :ends_at_label,
      :location, :confirmation, links: [ :label, :url ]
    )
    # A form submits links as a hash of index => {label, url}; the JSON API
    # sends a plain array. Normalise both to an array of hashes.
    if params.dig(:segment, :links).is_a?(ActionController::Parameters)
      permitted[:links] = params[:segment][:links].to_unsafe_h.values
        .map { |h| h.slice("label", "url") }.reject { |h| h["url"].blank? }
    end
    permitted
  end
end
