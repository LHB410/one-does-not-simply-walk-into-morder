class Path < ApplicationRecord
  has_many :milestones, -> { order(:sequence_order) }, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :users, through: :path_users
  has_many :daily_step_entries, dependent: :destroy

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
    if milestones.loaded?
      milestones
        .select { |m| m.sequence_order > current_milestone.sequence_order }
        .min_by(&:sequence_order)
    else
      milestones.where("sequence_order > ?", current_milestone.sequence_order).first
    end
  end

  def milestone_for_distance(miles)
    miles_val = miles.to_f.floor

    if milestones.loaded?
      reached = milestones
        .select { |m| m.cumulative_distance_miles <= miles_val }
        .max_by(&:cumulative_distance_miles)
      reached || milestones.min_by(&:cumulative_distance_miles)
    else
      base_relation = milestones.unscope(:order)
      reached = base_relation
        .where("cumulative_distance_miles <= ?", miles_val)
        .order(cumulative_distance_miles: :desc)
        .first
      reached || base_relation.order(cumulative_distance_miles: :asc).first
    end
  end


  def all_users_completed?
    !path_users.where("progress_percentage < 100").exists?
  end
end
