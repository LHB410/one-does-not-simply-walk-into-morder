class Step < ApplicationRecord
  belongs_to :user
  validates :total_steps, :steps_today, :steps_until_mordor,
            :steps_until_next_milestone, presence: true, numericality: { greater_than_or_equal_to: 0 }

  STEPS_PER_MILE = 2112

  def can_update_today?
    last_updated_date != Date.current
  end

  def total_miles
    (total_steps / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_today
    (steps_today / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_until_next_milestone
    (steps_until_next_milestone / STEPS_PER_MILE.to_f).round(2)
  end

  def miles_until_mordor
    (steps_until_mordor / STEPS_PER_MILE.to_f).round(2)
  end

  def add_steps(new_steps, force: false)
    return false unless can_update_today? || force

    self.steps_today = new_steps
    self.total_steps += new_steps
    self.last_updated_date = Date.current

    recalculate_distances
    save
  end

  private

  def recalculate_distances
  active_path = Path.current
  return unless active_path
  current_miles = total_steps / STEPS_PER_MILE.to_f

  # Calculate current milestone based on updated miles, not stale path_user.current_milestone
  # This ensures that when steps carry over past a milestone, we use the correct current milestone
  current_milestone = active_path.milestone_for_distance(current_miles)

  if current_milestone
    # Calculate remaining distance to Mordor from current position
    remaining_distance = active_path.total_distance_miles - current_miles
    self.steps_until_mordor = (remaining_distance * STEPS_PER_MILE).to_i

    # Find the next milestone after the current one
    next_milestone = active_path.next_milestone_after(current_milestone)
    if next_milestone
      distance_to_next = next_milestone.cumulative_distance_miles - current_miles
      self.steps_until_next_milestone = [ distance_to_next * STEPS_PER_MILE, 0 ].max.to_i
    else
      self.steps_until_next_milestone = 0 # No more milestones, journey complete
    end
  end
  end
end
