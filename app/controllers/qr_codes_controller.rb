class QrCodesController < ApplicationController
  before_action :set_segment

  # Store (or replace) the one QR image for a segment. Accepts base64 PNG bytes
  # in `image_data`, matching how a boarding pass or ticket QR arrives.
  def create
    @segment.qr_code&.destroy
    qr = @segment.build_qr_code(qr_params)
    if qr.save
      respond_to do |format|
        format.html { redirect_to @segment.trip, notice: "QR code attached." }
        format.json { head :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @segment.trip, alert: qr.errors.full_messages.to_sentence }
        format.json { render json: { errors: qr.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @segment.qr_code&.destroy
    respond_to do |format|
      format.html { redirect_to @segment.trip, notice: "QR code removed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_segment
    @segment = Segment.find(params[:segment_id])
  end

  def qr_params
    params.require(:qr_code).permit(:image_data, :source_url)
  end
end
