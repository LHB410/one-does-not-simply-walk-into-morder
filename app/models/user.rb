class User < ApplicationRecord
  # validations: false because group members have no individual password (they
  # authenticate against their group's shared password, so password_digest is
  # nil). We keep password=/authenticate and own the presence rule below.
  has_secure_password validations: false

  belongs_to :group, optional: true

  # PII encryption at rest (no plaintext in DB/backups/logs).
  # deterministic: true keeps find_by(email:) and the unique index working;
  # downcase: true normalizes case (deterministic encryption is exact-match).
  encrypts :email, deterministic: true, downcase: true
  encrypts :health_access_token
  encrypts :health_refresh_token

  has_one :step, dependent: :destroy
  has_many :path_users, dependent: :destroy
  has_many :paths, through: :path_users
  has_many :daily_step_entries, dependent: :destroy
  has_many :milestone_pin_purchases, dependent: :destroy
  has_many :purchased_pin_milestones, through: :milestone_pin_purchases, source: :milestone

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token_color, presence: true
  # Non-group accounts (admin/legacy, created manually) still set their own
  # password. Group members are exempt; runs only on create so existing rows
  # are never re-validated.
  validates :password, presence: true, on: :create, unless: :group_member?

  after_create :create_associated_step

  delegate :total_miles, to: :step

  def group_member?
    group_id.present?
  end

  def group_leader?
    group_id.present? && group&.leader_id == id
  end

  def health_connected?
    health_uid.present?
  end

  def health_needs_reconnect?
    health_uid.present? && health_access_token.blank?
  end

  def current_position_on_path(path)
    return nil unless path
    return path_users.detect { |pu| pu.path_id == path.id } if path_users.loaded?
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
    Path.current&.total_distance_miles_to_steps || 0
  end

  def calculate_initial_steps_to_next_milestone
    path = Path.current
    return 0 unless path

    # From the starting point (0 miles) the "next milestone" is the second one in order.
    next_milestone = path.milestones.order(:sequence_order).second
    next_milestone ? next_milestone.distance_from_previous_miles_to_steps : 0
  end
end
