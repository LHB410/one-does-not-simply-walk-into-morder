class RegistrationsController < ApplicationController
  def new
    return redirect_to root_path if logged_in?

    @registration = nil
  end

  def create
    @registration = registration_params
    return reject_without_agreement unless terms_accepted?

    leader = GroupRegistration.new(@registration).call

    session[:user_id] = leader.id
    redirect_to root_path, turbo: false
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def terms_accepted?
    params.dig(:registration, :terms_accepted) == "1"
  end

  def reject_without_agreement
    @error = "You must agree to the Terms of Service and Privacy Policy to sign up."
    render :new, status: :unprocessable_entity
  end

  def registration_params
    params.require(:registration).permit(
      :group_name, :group_password, :group_password_confirmation,
      :leader_name, :leader_email,
      members: [ :name, :email ]
    )
  end
end
