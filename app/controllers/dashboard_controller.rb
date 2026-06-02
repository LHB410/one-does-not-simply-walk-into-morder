# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    # Logged-out visitors get the sign up / log in entry screen (rendered in the view).
    return unless logged_in?

    # Scope to the current user's group so groups never see each other's members.
    # Ungrouped users (legacy fellowship + admin, group_id nil) see each other.
    @users = User.where(group_id: current_user.group_id)
                 .includes(:step, :milestone_pin_purchases, path_users: [ :current_milestone, :path, user: :step ])
    @active_path = Path.current
    # Use eager-loaded user from @users to avoid N+1 queries
    @current_user = @users.find { |u| u.id == current_user.id } || current_user
  end
end
