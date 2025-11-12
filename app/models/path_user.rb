class PathUser < ApplicationRecord
  belongs_to :path
  belongs_to :user

  belongs_to :current_milestone, class_name: "Milestone", optional: true

  validates :user_id, uniqueness: { scope: :path_id }

  def update_progress
    user_miles = user.step.total_steps / Step::STEPS_PER_MILE.to_f
    self.current_milestone = path.milestone_for_distance(user_miles)
    self.progress_percentage = (user_miles / path.total_distance_miles.to_f * 100).round(2)
    save
  end
end
