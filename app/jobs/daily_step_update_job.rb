class DailyStepUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily step update at #{Time.current}")

    steps_data = GoogleSheetsService.new.fetch_user_steps

    if steps_data.empty?
      Rails.logger.warn("No step data retrieved from Google Sheets")
      return
    end

    User.find_each do |user|
      next unless steps_data.key?(user.email.downcase)

      step = user.step
      next unless step.can_update_today?

      new_steps = steps_data[user.email.downcase]

      if step.add_steps(new_steps)
        # Update path progress
        active_path = Path.active.first
        path_user = user.current_position_on_path(active_path)
        path_user&.update_progress

        Rails.logger.info("Updated #{user.name}: +#{new_steps} steps")
      else
        Rails.logger.error("Failed to update #{user.name}: #{step.errors.full_messages}")
      end
    end

    # Check if we need to transition to Part 2
    active_path = Path.active.first
    if active_path&.all_users_completed? && active_path.part_number == 1
      PathTransitionService.new(active_path).transition_to_part_two
    end

    Rails.logger.info("Daily step update completed")
  end
end
