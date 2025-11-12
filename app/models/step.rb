class Step < ApplicationRecord
  belongs_to :user
  validates :total_steps, :steps_today, :steps_until_mordor,
            :steps_until_next_milestone, presence: true, numericality: { greater_than_or_equal_to: 0 }

  STEPS_PER_MILE = 2112

  def can_update_today?
    last_updated_date != Date.current
  end

  def total_miles
    raw_miles = total_steps / STEPS_PER_MILE.to_f
    rounded = raw_miles.round(2)
    puts "[Step#total_miles] user_id=#{user_id} total_steps=#{total_steps} raw_miles=#{raw_miles} rounded=#{rounded}"
    rounded
  end

  def miles_today
    raw = steps_today / STEPS_PER_MILE.to_f
    rounded = raw.round(2)
    puts "[Step#miles_today] user_id=#{user_id} steps_today=#{steps_today} raw=#{raw} rounded=#{rounded}"
    rounded
  end

  def miles_until_next_milestone
    raw = steps_until_next_milestone / STEPS_PER_MILE.to_f
    rounded = raw.round(2)
    puts "[Step#miles_until_next_milestone] user_id=#{user_id} steps_until_next_milestone=#{steps_until_next_milestone} raw=#{raw} rounded=#{rounded}"
    rounded
  end

  def miles_until_mordor
    raw = steps_until_mordor / STEPS_PER_MILE.to_f
    rounded = raw.round(2)
    puts "[Step#miles_until_mordor] user_id=#{user_id} steps_until_mordor=#{steps_until_mordor} raw=#{raw} rounded=#{rounded}"
    rounded
  end

  def add_steps(new_steps, force: false)
    return false unless can_update_today? || force

    self.steps_today = new_steps
    self.total_steps += new_steps
    self.last_updated_date = Date.current
    puts "[Step#add_steps] user_id=#{user_id} +#{new_steps} steps total_steps=#{total_steps} last_updated_date=#{last_updated_date} force=#{force}"

    recalculate_distances
    save
  end

  private

  def recalculate_distances
  active_path = Path.active.first
  return unless active_path

  path_user = user.current_position_on_path(active_path)
  current_milestone = path_user&.current_milestone || active_path.milestones.first # Use first milestone if user is at the start

  if current_milestone
    # If user is at the first milestone, assume it's the starting point (0 miles)
    remaining_distance = active_path.remaining_distance_from_milestone(current_milestone, total_miles)
    self.steps_until_mordor = (remaining_distance * STEPS_PER_MILE).to_i

    next_milestone = active_path.next_milestone_after(current_milestone)
    if next_milestone
      distance_to_next = next_milestone.cumulative_distance_miles - total_miles
      self.steps_until_next_milestone = (distance_to_next * STEPS_PER_MILE).to_i
    else
      self.steps_until_next_milestone = 0 # No more milestones, i.e., Mordor reached
    end
  end
  end
end
