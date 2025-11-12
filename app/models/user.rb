class User < ApplicationRecord
  has_secure_password

  has_one :step, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :paths, through: :path_users

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :token_color, presence: true

  after_create :create_associated_step

  scope :non_admin, -> { where(admin: false) }
  scope :admin_users, -> { where(admin: true) }

  def total_miles
    (step.total_steps * 0.0004735).round(2) # ~2,112 steps per mile average
  end

  def current_position_on_path(path)
    path_users.find_by(path: path)
  end

  private

  def create_associated_step
    create_step(
      steps_until_mordor: calculate_initial_steps_to_mordor,
      steps_until_next_milestone: calculate_initial_steps_to_next_milestone
    )
  end

  def calculate_initial_steps_to_mordor
    Path.active.first&.total_distance_miles_to_steps || 0
  end

  def calculate_initial_steps_to_next_milestone
    path = Path.active.first
    return 0 unless path

    # From the starting point (0 miles) the "next milestone" is the second one in order.
    next_milestone = path.milestones.order(:sequence_order).second
    next_milestone ? next_milestone.distance_from_previous_miles_to_steps : 0
  end
end
