require 'rails_helper'

RSpec.describe AccountClosure do
  subject(:close) { described_class.new(user).call }

  describe "Google Health revocation" do
    context "when the user is connected to Google Health" do
      let(:user) do
        create(:user).tap do |u|
          u.update!(
            health_uid: "UID",
            health_access_token: "access",
            health_refresh_token: "refresh",
            health_token_expires_at: 1.hour.from_now
          )
        end
      end

      before { allow(HealthClient).to receive(:revoke_token).and_return(true) }

      it "revokes the grant with Google using the refresh token" do
        close
        expect(HealthClient).to have_received(:revoke_token).with("refresh")
      end
    end

    context "when the user is not connected to Google Health" do
      let(:user) { create(:user) }

      before { allow(HealthClient).to receive(:revoke_token) }

      it "does not call the revoke endpoint" do
        close
        expect(HealthClient).not_to have_received(:revoke_token)
      end
    end
  end

  describe "data deletion" do
    include_context "active path with milestones"

    let(:user) { create(:user) }

    before do
      create(:path_user, user: user, path: active_path, current_milestone: shire)
      create(:daily_step_entry, user: user, path: active_path)
      MilestonePinPurchase.create!(user: user, milestone: shire)
    end

    it "destroys the user and cascades away all of their data" do
      step_id = user.step.id

      close

      expect(User.exists?(user.id)).to be(false)
      expect(Step.exists?(step_id)).to be(false)
      expect(DailyStepEntry.where(user_id: user.id)).to be_empty
      expect(PathUser.where(user_id: user.id)).to be_empty
      expect(MilestonePinPurchase.where(user_id: user.id)).to be_empty
    end
  end

  describe "group leadership" do
    context "when a leader with other members closes their account" do
      let(:group) { create(:group) }
      let(:user) { create(:user, :group_member, group: group) }
      let!(:earliest_member) { create(:user, :group_member, group: group) }
      let!(:later_member) { create(:user, :group_member, group: group) }

      before do
        # The leader joined first; earliest_member is the next-joined member.
        user.update_column(:created_at, 3.days.ago)
        earliest_member.update_column(:created_at, 2.days.ago)
        later_member.update_column(:created_at, 1.day.ago)
        group.update!(leader: user)
      end

      it "transfers leadership to the next-joined remaining member" do
        close
        expect(group.reload.leader).to eq(earliest_member)
      end

      it "keeps the group" do
        close
        expect(Group.exists?(group.id)).to be(true)
      end
    end

    context "when the sole leader of a group closes their account" do
      let(:group) { create(:group) }
      let(:user) { create(:user, :group_member, group: group) }

      before { group.update!(leader: user) }

      it "destroys the now-empty group" do
        close
        expect(Group.exists?(group.id)).to be(false)
      end
    end

    context "when an ordinary (non-leader) member closes their account" do
      let(:group) { create(:group) }
      let!(:leader) { create(:user, :group_member, group: group) }
      let(:user) { create(:user, :group_member, group: group) }

      before { group.update!(leader: leader) }

      it "leaves the group and its leader untouched" do
        close
        expect(Group.exists?(group.id)).to be(true)
        expect(group.reload.leader).to eq(leader)
      end
    end

    context "when an ungrouped user closes their account" do
      let(:user) { create(:user) }

      it "destroys the user without error" do
        expect { close }.not_to raise_error
        expect(User.exists?(user.id)).to be(false)
      end
    end
  end
end
