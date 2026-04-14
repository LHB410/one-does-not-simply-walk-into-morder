require "rails_helper"

RSpec.describe StatsHelper, type: :helper do
  include_context "user with path progress"

  describe "#pace_estimates" do
    context "when user has no daily step entries" do
      it "returns an empty array" do
        expect(helper.pace_estimates(user, active_path)).to eq([])
      end
    end

    context "when user has step history" do
      before do
        # 10,000 steps/day average over 3 days
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 2, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 1, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 10_000)
        # total: 30,000 steps = ~14.2 miles (30000 / 2112)
        user.step.update!(total_steps: 30_000)
      end

      it "returns estimated dates for upcoming milestones" do
        estimates = helper.pace_estimates(user, active_path)

        expect(estimates).to be_an(Array)
        expect(estimates).not_to be_empty
        expect(estimates.first).to include(:name, :miles_away, :estimated_date)
      end

      it "calculates estimates based on average daily steps" do
        estimates = helper.pace_estimates(user, active_path)

        # User has ~14.2 miles, Rivendell is at 400 miles => ~385.8 miles away
        # 10,000 steps/day = ~4.73 miles/day => ~81.5 days to Rivendell
        rivendell_estimate = estimates.find { |e| e[:name] == "Rivendell" }
        expect(rivendell_estimate).to be_present
        expect(rivendell_estimate[:miles_away]).to be > 0
        expect(rivendell_estimate[:estimated_date]).to be > Date.current
      end

      it "only includes milestones the user has not yet reached" do
        estimates = helper.pace_estimates(user, active_path)
        names = estimates.map { |e| e[:name] }

        # Shire is at 0 miles, user has 14+ miles, so Shire should not appear
        expect(names).not_to include("Shire")
      end
    end

    context "when user has reached the final milestone" do
      before do
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 10_000)
        user.step.update!(total_steps: active_path.total_distance_miles * Step::STEPS_PER_MILE)
      end

      it "returns an empty array" do
        expect(helper.pace_estimates(user, active_path)).to eq([])
      end
    end
  end

  describe "#personal_bests" do
    context "when user has no daily step entries" do
      it "returns an empty array" do
        expect(helper.personal_bests(user, active_path)).to eq([])
      end
    end

    context "when user has step history" do
      before do
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 4, steps: 5_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 3, steps: 15_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 2, steps: 8_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 1, steps: 20_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 12_000)
      end

      it "returns entries sorted by steps descending" do
        bests = helper.personal_bests(user, active_path)
        steps_values = bests.map { |b| b[:steps] }

        expect(steps_values).to eq(steps_values.sort.reverse)
      end

      it "defaults to limit of 5" do
        bests = helper.personal_bests(user, active_path)
        expect(bests.length).to eq(5)
      end

      it "respects custom limit" do
        bests = helper.personal_bests(user, active_path, limit: 3)
        expect(bests.length).to eq(3)
      end

      it "includes date and steps for each entry" do
        bests = helper.personal_bests(user, active_path)

        bests.each do |best|
          expect(best).to include(:date, :steps, :miles)
        end
      end

      it "returns the highest step day first" do
        bests = helper.personal_bests(user, active_path)
        expect(bests.first[:steps]).to eq(20_000)
      end
    end
  end
end
