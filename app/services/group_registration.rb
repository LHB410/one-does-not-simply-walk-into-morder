# Creates a group, its leader, and its members from sign-up params, all in one
# transaction, and places each user at the start of the active path so they
# appear on the map immediately. Returns the leader. Raises
# ActiveRecord::RecordInvalid (rolling everything back) if any record is invalid.
class GroupRegistration
  # Cycled across a group's members so each rider is visually distinct on the
  # map. token_color is required and members never pick one.
  TOKEN_COLORS = %w[
    #4169E1 #DC143C #228B22 #FF8C00 #8A2BE2 #20B2AA #B8860B #C71585
  ].freeze

  def initialize(registration)
    @registration = registration
  end

  def call
    ActiveRecord::Base.transaction do
      create_group
      create_leader_and_members
    end
    @leader
  end

  private

  def create_group
    @group = Group.create!(
      name: @registration[:group_name],
      password: @registration[:group_password],
      password_confirmation: @registration[:group_password_confirmation]
    )
  end

  def create_leader_and_members
    active_path = Path.current

    @leader = create_member(@registration[:leader_name], @registration[:leader_email], 0, active_path)
    @group.update!(leader: @leader)

    member_rows.each_with_index do |row, index|
      create_member(row[:name], row[:email], index + 1, active_path)
    end
  end

  def create_member(name, email, color_index, active_path)
    user = User.create!(
      name: name,
      email: email,
      group: @group,
      token_color: TOKEN_COLORS[color_index % TOKEN_COLORS.size]
      # NO password — members authenticate via the group's shared password.
    )
    PathUser.start_for(user, active_path)
    user
  end

  def member_rows
    Array(@registration[:members]).reject do |row|
      row[:name].blank? && row[:email].blank?
    end
  end
end
