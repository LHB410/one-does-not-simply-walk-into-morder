# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Loggable

  helper_method :current_user, :logged_in?

  # Run each request in the user's timezone so Date.current reflects their day.
  around_action :use_user_time_zone

  private

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
