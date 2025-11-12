require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_one(:step).dependent(:destroy) }
    it { should have_many(:path_users).dependent(:destroy) }
    it { should have_many(:paths).through(:path_users) }
  end

  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:token_color) }
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

  describe "#current_position_on_path" do
    include_context "user with path progress"

    it "returns the path_user record for given path" do
      position = user.current_position_on_path(active_path)

      expect(position).to eq(path_user)
      expect(position.current_milestone).to eq(shire)
    end
  end
end
