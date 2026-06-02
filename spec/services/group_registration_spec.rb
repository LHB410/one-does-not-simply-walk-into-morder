require 'rails_helper'

RSpec.describe GroupRegistration do
  let(:params) do
    {
      group_name: "The Fellowship",
      group_password: "speak-friend",
      group_password_confirmation: "speak-friend",
      leader_name: "Frodo",
      leader_email: "frodo@shire.me",
      members: [
        { name: "Sam", email: "sam@shire.me" },
        { name: "Merry", email: "merry@buckland.me" }
      ]
    }
  end

  describe "#call" do
    it "creates the group with its leader and members and returns the leader" do
      leader = described_class.new(params).call

      expect(Group.count).to eq(1)
      expect(leader.email).to eq("frodo@shire.me")
      expect(leader.group.leader).to eq(leader)
      expect(leader.group.users.pluck(:email)).to contain_exactly(
        "frodo@shire.me", "sam@shire.me", "merry@buckland.me"
      )
    end

    it "gives every member a token color and a step" do
      described_class.new(params).call
      group = Group.last

      expect(group.users.all? { |u| u.token_color.present? && u.step.present? }).to be true
    end

    it "lets members authenticate with the shared group password" do
      described_class.new(params).call
      member = User.find_by(email: "sam@shire.me")

      expect(member.group.authenticate("speak-friend")).to eq(member.group)
    end

    it "ignores blank member rows" do
      params[:members] << { name: "", email: "" }

      expect { described_class.new(params).call }.to change(User, :count).by(3)
    end

    it "rolls back everything when a member is invalid" do
      create(:user, email: "sam@shire.me") # duplicate email -> RecordInvalid

      expect { described_class.new(params).call }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Group.count).to eq(0)
      expect(User.where.not(email: "sam@shire.me")).to be_empty
    end

    context "with an active path" do
      include_context "active path with milestones"

      before { allow(Path).to receive(:current).and_return(active_path) }

      it "places the leader and every member at the start of the path" do
        described_class.new(params).call

        Group.last.users.each do |member|
          position = member.path_users.find_by(path: active_path)
          expect(position).to be_present
          expect(position.current_milestone).to eq(shire)
        end
      end
    end
  end
end
