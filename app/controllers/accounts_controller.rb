class AccountsController < ApplicationController
  before_action :require_login

  # Updates the current user's editable profile fields (currently just name).
  def update
    if current_user.update(account_params)
      redirect_to root_path, notice: "Your name has been updated."
    else
      redirect_to root_path,
                  alert: current_user.errors.full_messages.to_sentence.presence || "Could not update your account."
    end
  end

  # Permanently closes the current user's account and deletes all of their data,
  # then logs them out. See AccountClosure for the deletion details.
  def destroy
    AccountClosure.new(current_user).call
    reset_session
    redirect_to root_path, notice: "Your account and all your data have been deleted."
  rescue StandardError => e
    log(:error, "Account closure failed for user #{current_user.id}: #{e.class} — #{e.message}")
    redirect_to root_path, alert: "We couldn't close your account. Please try again."
  end

  private

  def account_params
    params.require(:user).permit(:name)
  end
end
