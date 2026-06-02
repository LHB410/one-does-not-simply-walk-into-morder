require 'rails_helper'

RSpec.describe Group, type: :model do
  describe "associations" do
    it { should have_many(:users).dependent(:nullify) }
    it { should belong_to(:leader).class_name("User").optional }
  end

  describe "validations" do
    subject { build(:group) }

    it { should validate_presence_of(:name) }
    it { should have_secure_password }
  end

  describe "password length" do
    it "is invalid with a password shorter than 8 characters" do
      group = build(:group, password: "short", password_confirmation: "short")

      expect(group).not_to be_valid
      expect(group.errors[:password]).to be_present
    end

    it "is valid with a password of at least 8 characters" do
      group = build(:group, password: "longenough", password_confirmation: "longenough")

      expect(group).to be_valid
    end
  end

  describe "shared password authentication" do
    let(:group) { create(:group, password: "speak-friend", password_confirmation: "speak-friend") }

    it "authenticates with the correct shared password" do
      expect(group.authenticate("speak-friend")).to eq(group)
    end

    it "does not authenticate with an incorrect password" do
      expect(group.authenticate("orc-speak")).to be_falsey
    end
  end

  describe "#leader_must_be_member" do
    let(:group) { create(:group) }

    it "is valid when the leader belongs to the group" do
      member = create(:user, :group_member, group: group)
      group.leader = member

      expect(group).to be_valid
    end

    it "is invalid when the leader is not a member of the group" do
      outsider = create(:user)
      group.leader = outsider

      expect(group).not_to be_valid
      expect(group.errors[:leader]).to be_present
    end
  end
end
