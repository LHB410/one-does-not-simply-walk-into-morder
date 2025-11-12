require 'rails_helper'

RSpec.describe PathTransitionService do
  include_context "active path with milestones"

  let!(:part_two) { create(:path, :part_two) }
  let!(:part_two_shire) do
    create(:milestone,
      path: part_two,
      name: "Shire",
      sequence_order: 0,
      cumulative_distance_miles: 0,
      distance_from_previous_miles: 0
    )
  end
  let!(:part_two_havens) do
    create(:milestone,
      path: part_two,
      name: "Grey Havens",
      sequence_order: 1,
      cumulative_distance_miles: 200,
      distance_from_previous_miles: 200
    )
  end

  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:path_user1) { create(:path_user, user: user1, path: active_path, progress_percentage: 100.0) }
  let!(:path_user2) { create(:path_user, user: user2, path: active_path, progress_percentage: 100.0) }

  let(:service) { described_class.new(active_path) }

  describe "#transition_to_part_two" do
    it "deactivates part 1" do
      service.transition_to_part_two

      expect(active_path.reload.active).to be false
    end

    it "activates part 2" do
      service.transition_to_part_two

      expect(part_two.reload.active).to be true
    end

    it "creates new path_user records for all users" do
      expect {
        service.transition_to_part_two
      }.to change { PathUser.where(path: part_two).count }.from(0).to(2)
    end

    it "resets users to start of part 2" do
      service.transition_to_part_two

      user1_part2 = user1.path_users.find_by(path: part_two)
      expect(user1_part2.current_milestone).to eq(part_two_shire)
      expect(user1_part2.progress_percentage).to eq(0.0)
    end

    it "maintains user total steps" do
      user1.step.update(total_steps: 2_112_000)

      expect {
        service.transition_to_part_two
      }.not_to change { user1.step.reload.total_steps }
    end

    it "updates step calculations for new path" do
      service.transition_to_part_two

      user1.step.reload
      expect(user1.step.steps_until_mordor).to eq(422_400) # 200 miles * 2112
    end

    context "when not part 1" do
      let(:service) { described_class.new(part_two) }

      it "does not transition" do
        expect {
          service.transition_to_part_two
        }.not_to change { part_two.reload.active }
      end
    end
  end
end
