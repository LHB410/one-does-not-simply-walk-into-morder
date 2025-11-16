class Path < ApplicationRecord
  has_many :milestones, -> { order(:sequence_order) }, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :users, through: :path_users

  validates :name, :part_number, :total_distance_miles, presence: true
  validates :part_number, inclusion: { in: [ 1, 2 ] }

  scope :active, -> { where(active: true) }
  scope :part_one, -> { where(part_number: 1) }

  def total_distance_miles_to_steps
    total_distance_miles * Step::STEPS_PER_MILE
  end

  def next_milestone_after(current_milestone)
    milestones.where("sequence_order > ?", current_milestone.sequence_order).first
  end

  def remaining_distance_from_milestone(milestone, current_user_miles)
    total_distance_miles - current_user_miles
  end

  def milestone_for_distance(miles)
    miles_int = miles.to_f.floor
    ordered = milestones.reorder(nil)

    reached = ordered
      .where("cumulative_distance_miles <= ?", miles_int)
      .order(cumulative_distance_miles: :desc)
      .first

    reached || ordered.order(cumulative_distance_miles: :asc).first
  end


  def all_users_completed?
    path_users.all? { |pu| pu.progress_percentage >= 100.0 }
  end
end
