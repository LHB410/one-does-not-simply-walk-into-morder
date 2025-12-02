class StepsController < ApplicationController
  before_action :require_login

  def report
    @active_path = Path.current
    per_page = 10
    @page = params[:page].to_i
    @page = 1 if @page < 1

    if @active_path
      total_days = DailyStepEntry.total_days_for(user: current_user, path: @active_path)
      @total_pages = (total_days / per_page.to_f).ceil
      @total_pages = 1 if @total_pages.zero?

      @daily_rows = DailyStepEntry.daily_totals_for(
        user: current_user,
        path: @active_path,
        page: @page,
        per_page: per_page
      )
    else
      @total_pages = 1
      @daily_rows = DailyStepEntry.none
    end
  end

  def update
    @step = current_user.step

    override = current_user.admin? || params[:force].present?
    unless @step.can_update_today? || override
      return render json: {
        error: "Steps already updated today"
      }, status: :unprocessable_entity
    end

    steps_to_add = params[:steps].to_i

    if steps_to_add <= 0
      return render json: {
        error: "Steps must be greater than 0"
      }, status: :unprocessable_entity
    end

    if @step.add_steps(steps_to_add, force: override)
      update_user_path_progress

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Steps updated successfully!" }
        format.turbo_stream { redirect_to root_path, status: :see_other }
        format.json { render json: { success: true, step: step_json(@step) }, status: :ok }
        format.any { head :ok }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to root_path,
          alert: "Failed to update steps: #{@step.errors.full_messages.join(', ')}"
        }
        format.turbo_stream { redirect_to root_path, status: :see_other }
        format.json { render json: { error: "Failed to update steps" }, status: :unprocessable_entity }
        format.any { head :unprocessable_entity }
      end
    end
  end

  def admin_update
    unless current_user.admin?
      return render json: { error: "Unauthorized" }, status: :forbidden
    end

    @step = Step.find(params[:id])
    steps_to_add = params[:steps].to_i

    if @step.add_steps(steps_to_add, force: true)
      user = @step.user
      user.current_position_on_path(Path.current)&.update_progress

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Steps updated successfully!" }
        format.turbo_stream { redirect_to root_path, status: :see_other }
        format.json { render json: { success: true, step: step_json(@step) }, status: :ok }
        format.any { head :ok }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to root_path,
          alert: "Failed to update steps: #{@step.errors.full_messages.join(', ')}"
        }
        format.turbo_stream { redirect_to root_path, status: :see_other }
        format.json { render json: { error: "Failed to update steps" }, status: :unprocessable_entity }
        format.any { head :unprocessable_entity }
      end
    end
  end

  private

  def update_user_path_progress
    active_path = Path.current
    path_user = current_user.current_position_on_path(active_path)
    path_user&.update_progress
  end

  def step_json(step)
    {
      total_steps: step.total_steps,
      steps_today: step.steps_today,
      total_miles: step.total_miles,
      miles_today: step.miles_today,
      miles_until_next_milestone: step.miles_until_next_milestone,
      miles_until_mordor: step.miles_until_mordor,
      can_update_today: step.can_update_today?
    }
  end
end
