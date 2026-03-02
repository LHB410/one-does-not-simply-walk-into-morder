require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_one(:step).dependent(:destroy) }
    it { should have_many(:path_users).dependent(:destroy) }
    it { should have_many(:paths).through(:path_users) }
    it { should have_many(:daily_step_entries).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:token_color) }

    it { should allow_value("user@example.com").for(:email) }
    it { should_not allow_value("not-an-email").for(:email) }
    it { should_not allow_value("@no-local.com").for(:email) }
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

  describe "#fitbit_connected?" do
    let(:user) { create(:user) }

    it "returns true when fitbit_uid is present" do
      user.update!(fitbit_uid: "ABC123")
      expect(user.fitbit_connected?).to be true
    end

    it "returns false when fitbit_uid is nil" do
      expect(user.fitbit_connected?).to be false
    end
  end

  describe "#fitbit_needs_reconnect?" do
    let(:user) { create(:user) }

    it "returns true when uid is present but access token is blank" do
      user.update!(fitbit_uid: "ABC123", fitbit_access_token: nil)
      expect(user.fitbit_needs_reconnect?).to be true
    end

    it "returns false when fully connected" do
      user.update!(fitbit_uid: "ABC123", fitbit_access_token: "token")
      expect(user.fitbit_needs_reconnect?).to be false
    end

    it "returns false when never connected" do
      expect(user.fitbit_needs_reconnect?).to be false
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
