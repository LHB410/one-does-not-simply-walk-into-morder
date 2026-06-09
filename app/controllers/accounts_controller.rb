class AccountsController < ApplicationController
  before_action :require_login

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
end
