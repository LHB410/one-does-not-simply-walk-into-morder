class RegistrationsController < ApplicationController
  def new
    return redirect_to root_path if logged_in?

    @registration = nil
  end

  def create
    @registration = registration_params
    leader = GroupRegistration.new(@registration).call

    session[:user_id] = leader.id
    redirect_to root_path, turbo: false
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def registration_params
    params.require(:registration).permit(
      :group_name, :group_password, :group_password_confirmation,
      :leader_name, :leader_email,
      members: [ :name, :email ]
    )
  end
end
