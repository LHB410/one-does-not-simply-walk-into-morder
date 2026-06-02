class GroupsController < ApplicationController
  before_action :require_login
  before_action :require_group_leader

  # Rotate the group's shared password. Only the leader reaches this action.
  def update_password
    if current_user.group.update(password_params)
      redirect_to root_path, notice: "Group password updated"
    else
      redirect_to root_path, alert: current_user.group.errors.full_messages.to_sentence.presence || "Could not update password"
    end
  end

  private

  def require_group_leader
    return if current_user&.group_leader?

    # Mirrors the admin-only guard in StepsController#admin_update.
    render json: { error: "Unauthorized" }, status: :forbidden
  end

  def password_params
    params.require(:group).permit(:password, :password_confirmation)
  end
end
