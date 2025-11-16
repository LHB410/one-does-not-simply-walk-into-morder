# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    if logged_in?
      @users = User.includes(:step, path_users: [ :current_milestone, :path ]).all
      @active_path = Path.active.includes(milestones: []).first
      @current_user = current_user
    else
      # Show login modal if not logged in
      @show_login_modal = true
    end
  end
end
