# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Loggable

  helper_method :current_user, :logged_in?

  # Run every request in the acting user's timezone so Date.current — and so the
  # date stamped on a manually-logged step — reflects *their* day, not the
  # server's UTC day. Logged-out requests (and users with no saved zone) fall
  # back to the app default. The sync job sets its own zone, so it is unaffected.
  around_action :use_user_time_zone

  private

  def use_user_time_zone(&block)
    Time.use_zone(current_user_time_zone, &block)
  end

  def current_user_time_zone
    current_user&.timezone.presence || Time.zone
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    return if logged_in?
    redirect_to root_path, alert: "Please log in to continue"
  end
end
