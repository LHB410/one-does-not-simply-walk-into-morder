class Group < ApplicationRecord
  # One shared password per group (bcrypt digest). Members authenticate against
  # this; only the group leader may change it (enforced in GroupsController).
  has_secure_password

  has_many :users, dependent: :nullify
  belongs_to :leader, class_name: "User", optional: true

  validates :name, presence: true
  # has_secure_password already requires a password on create; this adds the
  # minimum-length policy. allow_nil lets the leader update other attributes
  # without re-entering the password.
  validates :password, length: { minimum: 8 }, allow_nil: true

  validate :leader_must_be_member

  private

  def leader_must_be_member
    return if leader.nil?
    return if users.include?(leader)

    errors.add(:leader, "must be a member of the group")
  end
end
