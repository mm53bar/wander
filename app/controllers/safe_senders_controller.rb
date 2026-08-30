class SafeSendersController < ApplicationController
  def index
    @safe_senders = SafeSender.all
    @safe_sender = SafeSender.new
    @allowed_senders = AllowedSender.all
    @allowed_sender = AllowedSender.new
  end

  def create
    @safe_sender = SafeSender.new(safe_sender_params)
    if @safe_sender.save
      redirect_to safe_senders_path, notice: "Added #{@safe_sender.value}."
    else
      @safe_senders = SafeSender.all
      @allowed_senders = AllowedSender.all
      @allowed_sender = AllowedSender.new
      render :index, status: :unprocessable_entity
    end
  end

  def update
    sender = SafeSender.find(params[:id])
    sender.update(safe_sender_params)
    redirect_to safe_senders_path, notice: "Updated #{sender.value}."
  end

  def destroy
    sender = SafeSender.find(params[:id])
    sender.destroy
    redirect_to safe_senders_path, notice: "Removed #{sender.value}.", status: :see_other
  end

  private

  def safe_sender_params
    params.require(:safe_sender).permit(:value, :name, :active)
  end
end
