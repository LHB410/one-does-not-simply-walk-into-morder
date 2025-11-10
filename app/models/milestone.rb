class Milestone < ApplicationRecord
  belongs_to :path

  validates :name, :distance_from_previous_miles, :cumulative_distance_miles,
            :sequence_order, presence: true
  validates :sequence_order, uniqueness: { scope: :path_id }
  validates :map_position_x, :map_position_y, presence: true

  def distance_from_previous_miles_to_steps
    distance_from_previous_miles * Step::STEPS_PER_MILE
  end
end
