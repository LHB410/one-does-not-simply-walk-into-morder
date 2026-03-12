class MilestonePinsController < ApplicationController
  before_action :require_login
  before_action :set_milestone, except: :dismiss

  def new
  end

  def create
    current_user.milestone_pin_purchases.find_or_create_by!(milestone: @milestone)
    @path = Path.current
    respond_to { |f| f.turbo_stream }
  end

  def dismiss
  end

  private

  def set_milestone
    @milestone = Milestone.find(params[:milestone_id])
  end
end
