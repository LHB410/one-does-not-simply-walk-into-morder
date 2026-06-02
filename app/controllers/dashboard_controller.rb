# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    # Logged-out visitors get the sign up / log in entry screen (rendered in the view).
    return unless logged_in?

    @users = User.includes(:step, :milestone_pin_purchases, path_users: [ :current_milestone, :path, user: :step ]).all
    @active_path = Path.current
    # Use eager-loaded user from @users to avoid N+1 queries
    @current_user = @users.find { |u| u.id == current_user.id } || current_user
  end
end
