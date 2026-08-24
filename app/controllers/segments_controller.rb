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

  private

  def segment_params
    permitted = params.require(:segment).permit(
      :kind, :emoji, :summary, :starts_at, :ends_at, :starts_at_label, :ends_at_label,
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
