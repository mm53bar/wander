# Addresses wander will reply to when a booking needs handling by hand. Shares
# the Settings page with SafeSendersController — deliberately a separate list,
# see AllowedSender.
class AllowedSendersController < ApplicationController
  def create
    sender = AllowedSender.new(allowed_sender_params)
    if sender.save
      redirect_to settings_path, notice: "Now replying to #{sender.address}."
    else
      redirect_to settings_path, alert: sender.errors.full_messages.to_sentence
    end
  end

  def update
    sender = AllowedSender.find(params[:id])
    sender.update(allowed_sender_params)
    redirect_to settings_path, notice: "Updated #{sender.address}."
  end

  def destroy
    sender = AllowedSender.find(params[:id])
    sender.destroy
    redirect_to settings_path, notice: "Removed #{sender.address}.", status: :see_other
  end

  private

  def allowed_sender_params
    params.require(:allowed_sender).permit(:address, :note, :active)
  end
end
