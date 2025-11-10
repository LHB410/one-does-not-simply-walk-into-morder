class StepsController < ApplicationController
  before_action :require_login

  def index
    @users = User.includes(:step, path_users: [ :path, :current_milestone ]).all
    @active_path = Path.active.includes(:milestones).first
    @current_user_step = current_user.step
  end

  def update
    @step = current_user.step

    unless @step.can_update_today?
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

    if @step.add_steps(steps_to_add)
      update_user_path_progress

      respond_to do |format|
        format.html { redirect_to root_path, notice: "Steps updated successfully!" }
        format.json {
          render json: {
            success: true,
            step: step_json(@step),
            message: "Added #{steps_to_add} steps (#{@step.miles_today} miles)"
          }
        }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to root_path,
          alert: "Failed to update steps: #{@step.errors.full_messages.join(', ')}"
        }
        format.json {
          render json: {
            error: @step.errors.full_messages
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def admin_update
    unless current_user.admin?
      return render json: { error: "Unauthorized" }, status: :forbidden
    end

    @step = Step.find(params[:id])
    steps_to_add = params[:steps].to_i

    if @step.add_steps(steps_to_add)
      user = @step.user
      user.current_position_on_path(Path.active.first)&.update_progress

      render json: {
        success: true,
        step: step_json(@step)
      }
    else
      render json: {
        error: @step.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def update_user_path_progress
    active_path = Path.active.first
    path_user = current_user.current_position_on_path(active_path)
    path_user&.update_progress

    check_path_completion(active_path)
  end

  def check_path_completion(path)
    return unless path.all_users_completed?

    if path.part_number == 1
      # Activate Part 2 and reset user positions
      PathTransitionService.new(path).transition_to_part_two
    end
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
