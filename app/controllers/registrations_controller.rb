class RegistrationsController < ApplicationController
  # Token colors cycled across a group's members so each rider is visually
  # distinct on the map. token_color is required and members never pick one.
  TOKEN_COLORS = %w[
    #4169E1 #DC143C #228B22 #FF8C00 #8A2BE2 #20B2AA #B8860B #C71585
  ].freeze

  def new
    return redirect_to root_path if logged_in?

    @registration = nil
  end

  def create
    @registration = registration_params
    leader = build_and_save_group_with_members

    session[:user_id] = leader.id
    redirect_to root_path, turbo: false
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  # Everything happens in one transaction: if any member is invalid (e.g. a
  # duplicate email), the group, leader, and earlier members all roll back.
  def build_and_save_group_with_members
    leader = nil

    ActiveRecord::Base.transaction do
      @group = Group.create!(
        name: @registration[:group_name],
        password: @registration[:group_password],
        password_confirmation: @registration[:group_password_confirmation]
      )

      # Warm Path.current once so each member's Step seed doesn't re-resolve it.
      Path.current

      leader = build_member(@registration[:leader_name], @registration[:leader_email], 0)
      leader.save!
      @group.update!(leader: leader)

      member_rows.each_with_index do |row, index|
        build_member(row[:name], row[:email], index + 1).save!
      end
    end

    leader
  end

  def build_member(name, email, color_index)
    User.new(
      name: name,
      email: email,
      group: @group,
      token_color: TOKEN_COLORS[color_index % TOKEN_COLORS.size]
    )
  end

  def member_rows
    Array(@registration[:members]).reject do |row|
      row[:name].blank? && row[:email].blank?
    end
  end

  def registration_params
    params.require(:registration).permit(
      :group_name, :group_password, :group_password_confirmation,
      :leader_name, :leader_email,
      members: [ :name, :email ]
    )
  end
end
