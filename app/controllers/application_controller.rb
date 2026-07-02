# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Loggable

  # Log out idle sessions and cap absolute session length (ASVS V3).
  SESSION_IDLE_TIMEOUT = 2.hours
  SESSION_ABSOLUTE_TIMEOUT = 24.hours

  helper_method :current_user, :logged_in?

  # Run each request in the user's timezone so Date.current reflects their day.
  around_action :use_user_time_zone
  before_action :enforce_session_timeout

  private

  # Timestamps are UTC epochs so the per-request timezone can't skew the maths.
  def enforce_session_timeout
    return unless logged_in?

    now = Time.current.to_i
    idle = session[:last_seen_at] && now - session[:last_seen_at] > SESSION_IDLE_TIMEOUT
    capped = session[:created_at] && now - session[:created_at] > SESSION_ABSOLUTE_TIMEOUT

    if idle || capped
      reset_session
      @current_user = nil
      redirect_to root_path, alert: "Your session expired. Please log in again."
    else
      session[:last_seen_at] = now
    end
  end

  def use_user_time_zone(&block)
    Time.use_zone(request_time_zone, &block)
  end

  # Saved zone first, then a (validated) browser param, then the default.
  def request_time_zone
    current_user&.timezone.presence ||
      Time.find_zone(params[:timezone].to_s) ||
      Time.zone
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
