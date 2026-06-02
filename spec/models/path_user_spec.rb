require 'rails_helper'

RSpec.describe PathUser, type: :model do
  describe "associations" do
    it { should belong_to(:path) }
    it { should belong_to(:user) }
    it { should belong_to(:current_milestone).class_name('Milestone').optional }
  end

  describe "validations" do
    subject { build(:path_user) }

    it { should validate_uniqueness_of(:user_id).scoped_to(:path_id) }
  end

  describe ".start_for" do
    include_context "active path with milestones"

    it "creates a starting position at the first milestone with zero progress" do
      user = create(:user)

      position = described_class.start_for(user, active_path)

      expect(position).to be_persisted
      expect(position.path).to eq(active_path)
      expect(position.current_milestone).to eq(shire)
      expect(position.progress_percentage).to eq(0.0)
    end

    it "does nothing and returns nil when there is no active path" do
      user = create(:user)

      expect { @result = described_class.start_for(user, nil) }.not_to change(PathUser, :count)
      expect(@result).to be_nil
    end
  end

  describe "#update_progress" do
    include_context "user with path progress"

    it "updates current milestone based on user miles" do
      user.step.update(total_steps: 844_800) # 400 miles
      allow_any_instance_of(User).to receive(:total_miles).and_return(400)

      path_user.update_progress

      expect(path_user.current_milestone).to eq(rivendell)
      expect(path_user.progress_percentage).to eq(40.0)
    end
  end
end
