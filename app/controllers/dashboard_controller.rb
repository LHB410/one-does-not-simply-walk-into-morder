class DashboardController < ApplicationController
  before_action :require_login

  def index
    @users = User.includes(:step, path_users: [ :current_milestone ]).all
    @active_path = Path.active.includes(milestones: []).first
    @current_user = current_user
  end
end
