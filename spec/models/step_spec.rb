require 'rails_helper'

RSpec.describe Step, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:total_steps) }
    it { should validate_presence_of(:steps_today) }
    it { should validate_presence_of(:steps_until_mordor) }
    it { should validate_presence_of(:steps_until_next_milestone) }
  end

  describe "#can_update_today?" do
    let(:step) { create(:user).step }

    context "when never updated" do
      it "returns true" do
        expect(step.can_update_today?).to be true
      end
    end

    context "when updated today" do
      before { step.update(last_updated_date: Date.current) }

      it "returns false" do
        expect(step.can_update_today?).to be false
      end
    end

    context "when updated yesterday" do
      before { step.update(last_updated_date: Date.yesterday) }

      it "returns true" do
        expect(step.can_update_today?).to be true
      end
    end
  end

  describe "conversion methods" do
    let(:step) do
      user = create(:user)
      user.step.update(total_steps: 2112, steps_today: 1056)
      user.step
    end

    it "converts steps to miles correctly" do
      expect(step.total_miles).to eq(1.0)
      expect(step.miles_today).to eq(0.5)
    end
  end

  describe "#add_steps" do
    include_context "user with path progress"

    let(:step) { user.step }

    context "when can update today" do
      it "adds steps and updates totals" do
        expect {
          step.add_steps(5000)
        }.to change { step.total_steps }.by(5000)
          .and change { step.steps_today }.to(5000)
          .and change { step.last_updated_date }.to(Date.current)
      end

      it "recalculates distances" do
        step.add_steps(844_800) # 400 miles to Rivendell

        expect(step.steps_until_next_milestone).to be < 844_800
      end
    end

    context "when already updated today" do
      before { step.update(last_updated_date: Date.current) }

      it "does not add steps" do
        expect {
          step.add_steps(5000)
        }.not_to change { step.total_steps }
      end

      it "returns false" do
        expect(step.add_steps(5000)).to be false
      end
    end
  end
end
