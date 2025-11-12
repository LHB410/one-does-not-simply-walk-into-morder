require 'rails_helper'

RSpec.describe Path, type: :model do
  describe "associations" do
    it { should have_many(:milestones).dependent(:destroy) }
    it { should have_many(:path_users).dependent(:destroy) }
    it { should have_many(:users).through(:path_users) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:part_number) }
    it { should validate_presence_of(:total_distance_miles) }
    it { should validate_inclusion_of(:part_number).in_array([ 1, 2 ]) }
  end

  describe "scopes" do
    let!(:active_path) { create(:path, :active) }
    let!(:inactive_path) { create(:path) }

    it "returns only active paths" do
      expect(Path.active).to contain_exactly(active_path)
    end
  end

  describe "#next_milestone_after" do
    include_context "active path with milestones"

    it "returns the next milestone in sequence" do
      expect(active_path.next_milestone_after(shire)).to eq(rivendell)
      expect(active_path.next_milestone_after(rivendell)).to eq(mordor)
    end

    it "returns nil when at last milestone" do
      expect(active_path.next_milestone_after(mordor)).to be_nil
    end
  end

  describe "#milestone_for_distance" do
    include_context "active path with milestones"

    it "returns the appropriate milestone for given distance" do
      expect(active_path.milestone_for_distance(0)).to eq(shire)
      expect(active_path.milestone_for_distance(200)).to eq(shire)
      expect(active_path.milestone_for_distance(500)).to eq(rivendell)
    end
  end

  describe "#all_users_completed?" do
    include_context "active path with milestones"

    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:path_user1) { create(:path_user, user: user1, path: active_path, progress_percentage: 100.0) }
    let!(:path_user2) { create(:path_user, user: user2, path: active_path, progress_percentage: 100.0) }

    it "returns true when all users completed" do
      expect(active_path.all_users_completed?).to be true
    end

    it "returns false when any user incomplete" do
      path_user2.update(progress_percentage: 50.0)

      expect(active_path.all_users_completed?).to be false
    end
  end
end
