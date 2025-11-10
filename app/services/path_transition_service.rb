class PathTransitionService
  def initialize(current_path)
    @current_path = current_path
  end

  def transition_to_part_two
    return unless @current_path.part_number == 1

    ActiveRecord::Base.transaction do
      # Deactivate Part 1
      @current_path.update!(active: false)

      # Activate Part 2
      part_two = Path.part_two.first
      part_two.update!(active: true)

      # Reset all users to start of Part 2 (Shire)
      User.find_each do |user|
        # Maintain total_steps but reset position
        PathUser.create!(
          user: user,
          path: part_two,
          current_milestone: part_two.milestones.first,
          progress_percentage: 0.0
        )

        # Update step calculations for new path
        step = user.step
        step.update!(
          steps_until_mordor: part_two.total_distance_miles_to_steps,
          steps_until_next_milestone: part_two.milestones.second&.distance_from_previous_miles_to_steps || 0
        )
      end
    end

    Rails.logger.info("Transitioned all users from Part 1 to Part 2")
  end
end
