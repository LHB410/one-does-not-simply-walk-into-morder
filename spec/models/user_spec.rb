require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_one(:step).dependent(:destroy) }
    it { should have_many(:path_users).dependent(:destroy) }
    it { should have_many(:paths).through(:path_users) }
    it { should have_many(:daily_step_entries).dependent(:destroy) }
    it { should belong_to(:group).optional }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:token_color) }

    it { should allow_value("user@example.com").for(:email) }
    it { should_not allow_value("not-an-email").for(:email) }
    it { should_not allow_value("@no-local.com").for(:email) }
  end

  # Email uses deterministic Active Record Encryption with downcase, so the
  # shoulda validate_uniqueness_of matcher (which assumes case-sensitive
  # behavior) doesn't fit; these explicit examples cover uniqueness + the
  # encryption guarantees instead.
  describe "email uniqueness and encryption" do
    it "rejects a duplicate email" do
      create(:user, email: "frodo@shire.me")
      dup = build(:user, email: "frodo@shire.me")

      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to include("has already been taken")
    end

    it "treats email case-insensitively (deterministic + downcase)" do
      create(:user, email: "frodo@shire.me")
      dup = build(:user, email: "FRODO@SHIRE.ME")

      expect(dup).not_to be_valid
    end

    it "finds a user by email regardless of case" do
      user = create(:user, email: "samwise@shire.me")

      expect(User.find_by(email: "SAMWISE@SHIRE.ME")).to eq(user)
    end

    it "stores the email encrypted at rest (no plaintext in the column)" do
      user = create(:user, email: "pippin@shire.me")

      expect(user.ciphertext_for(:email)).not_to include("pippin@shire.me")
      expect(user.reload.email).to eq("pippin@shire.me")
    end
  end

  describe "health token encryption" do
    it "round-trips encrypted health tokens without storing plaintext" do
      user = create(:user)
      user.update!(health_access_token: "secret-token-123")

      expect(user.reload.health_access_token).to eq("secret-token-123")
      expect(user.ciphertext_for(:health_access_token)).not_to include("secret-token-123")
    end
  end

  describe "group membership" do
    describe "#group_member?" do
      it "is true when the user belongs to a group" do
        expect(create(:user, :group_member).group_member?).to be true
      end

      it "is false for a user with no group" do
        expect(create(:user).group_member?).to be false
      end
    end

    describe "#group_leader?" do
      let(:group) { create(:group) }
      let(:member) { create(:user, :group_member, group: group) }

      it "is true when the user leads their group" do
        group.update!(leader: member)

        expect(member.reload.group_leader?).to be true
      end

      it "is false for a member who is not the leader" do
        leader = create(:user, :group_member, group: group)
        group.update!(leader: leader)

        expect(member.reload.group_leader?).to be false
      end

      it "is false for a user with no group" do
        expect(create(:user).group_leader?).to be false
      end
    end
  end

  describe "password requirements" do
    it "requires a password for a non-group user on create" do
      user = build(:user, password: nil, password_confirmation: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "allows a group member to be created without an individual password" do
      member = build(:user, :group_member, group: create(:group))

      expect(member).to be_valid
    end
  end

  # Guards the user's concern that the auth/validation changes could corrupt or
  # lock out pre-existing accounts. A legacy/admin user (own password, no group)
  # must stay valid and able to authenticate.
  describe "regression: pre-existing non-group users are unaffected" do
    it "remains valid and authenticates with its own password" do
      user = create(:user, password: "password123", password_confirmation: "password123")

      expect(user.group_id).to be_nil
      expect(user).to be_valid
      expect(user.reload.authenticate("password123")).to eq(user)
    end
  end

  describe "callbacks" do
    context "after create" do
      it "creates associated step record" do
        user = create(:user)

        expect(user.step).to be_present
        expect(user.step.total_steps).to eq(0)
      end
    end
  end

  describe "#total_miles" do
    it "converts total steps to miles" do
      user = create(:user)
      user.step.update(total_steps: 2112)

      expect(user.total_miles).to eq(1.0)
    end
  end

  describe "#health_connected?" do
    let(:user) { create(:user) }

    it "returns true when health_uid is present" do
      user.update!(health_uid: "ABC123")
      expect(user.health_connected?).to be true
    end

    it "returns false when health_uid is nil" do
      expect(user.health_connected?).to be false
    end
  end

  describe "#health_needs_reconnect?" do
    let(:user) { create(:user) }

    it "returns true when uid is present but access token is blank" do
      user.update!(health_uid: "ABC123", health_access_token: nil)
      expect(user.health_needs_reconnect?).to be true
    end

    it "returns false when fully connected" do
      user.update!(health_uid: "ABC123", health_access_token: "token")
      expect(user.health_needs_reconnect?).to be false
    end

    it "returns false when never connected" do
      expect(user.health_needs_reconnect?).to be false
    end
  end

  describe "#current_position_on_path" do
    include_context "user with path progress"

    it "returns the path_user record for given path" do
      position = user.current_position_on_path(active_path)

      expect(position).to eq(path_user)
      expect(position.current_milestone).to eq(shire)
    end
  end
end
