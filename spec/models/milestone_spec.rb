require 'rails_helper'

RSpec.describe Milestone, type: :model do
  describe "associations" do
    it { should belong_to(:path) }
  end

  describe "validations" do
    subject { build(:milestone) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:distance_from_previous_miles) }
    it { should validate_presence_of(:cumulative_distance_miles) }
    it { should validate_presence_of(:sequence_order) }
    it { should validate_presence_of(:map_position_x) }
    it { should validate_presence_of(:map_position_y) }
    it { should validate_uniqueness_of(:sequence_order).scoped_to(:path_id) }
  end

  describe "#distance_from_previous_miles_to_steps" do
    let(:milestone) { create(:milestone, distance_from_previous_miles: 100) }

    it "converts miles to steps" do
      expect(milestone.distance_from_previous_miles_to_steps).to eq(211_200)
    end
  end
end
