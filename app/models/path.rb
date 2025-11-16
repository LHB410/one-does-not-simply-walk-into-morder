class Path < ApplicationRecord
  has_many :milestones, -> { order(:sequence_order) }, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :users, through: :path_users

  validates :name, :part_number, :total_distance_miles, presence: true
  validates :part_number, inclusion: { in: [ 1, 2 ] }

  scope :active, -> { where(active: true) }

  # Memoized class method to get the current active path
  # Since there's only one active path that never changes, this caches the result
  # to avoid repeated database queries throughout the application
  def self.current
    return @current_path if defined?(@current_path)

    @current_path = active.includes(:milestones).first
  end

  # Clear the cached current path (useful for testing)
  def self.clear_current_cache!
    @current_path = nil
  end

  def total_distance_miles_to_steps
    total_distance_miles * Step::STEPS_PER_MILE
  end

  def next_milestone_after(current_milestone)
    milestones.where("sequence_order > ?", current_milestone.sequence_order).first
  end

  def milestone_for_distance(miles)
    miles_int = miles.to_f.floor

    # Remove default sequence_order and order by cumulative_distance_miles instead
    # This is more efficient than ordering by both sequence_order and cumulative_distance_miles
    base_relation = milestones.unscope(:order)

    # Find the highest milestone where cumulative_distance_miles <= miles_int
    reached = base_relation
      .where("cumulative_distance_miles <= ?", miles_int)
      .order(cumulative_distance_miles: :desc)
      .first

    # Fallback to first milestone if none reached (shouldn't happen, but safe)
    reached || base_relation.order(cumulative_distance_miles: :asc).first
  end


  def all_users_completed?
    return @all_users_completed if defined?(@all_users_completed)

    # Use SQL aggregation instead of loading all records into memory
    # Returns true if no path_users have progress < 100%
    @all_users_completed = !path_users.where("progress_percentage < 100").exists?
  end
end
