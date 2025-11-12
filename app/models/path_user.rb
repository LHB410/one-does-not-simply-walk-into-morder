class PathUser < ApplicationRecord
  belongs_to :path
  belongs_to :user

  belongs_to :current_milestone, class_name: "Milestone", optional: true

  validates :user_id, uniqueness: { scope: :path_id }

  def update_progress
    user_miles = user.total_miles
    before = current_milestone&.name
    self.current_milestone = path.milestone_for_distance(user_miles)
    after = current_milestone&.name
    self.progress_percentage = (user_miles / path.total_distance_miles.to_f * 100).round(2)
    puts "[PathUser#update_progress] user_id=#{user_id} miles=#{user_miles} milestone: #{before} -> #{after} progress=#{progress_percentage}%"
    save
  end
end
