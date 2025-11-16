# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    if logged_in?
      @users = User.includes(:step, path_users: [ :current_milestone, :path, user: :step ]).all
      @active_path = Path.current
      # Use eager-loaded user from @users to avoid N+1 queries
      @current_user = @users.find { |u| u.id == current_user.id } || current_user
    else
      # Show login modal if not logged in
      @show_login_modal = true
    end
  end
end
