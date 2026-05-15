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
        # 10,000 steps/day average over 3 consecutive days
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 2, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 1, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 10_000)
        # total: 30,000 steps = ~14.2 miles (30000 / 2112)
        # 3 calendar days from first entry to today => avg 10,000 steps/day
        user.step.update!(total_steps: 30_000)
      end

      it "returns estimated dates for upcoming milestones" do
        estimates = helper.pace_estimates(user, active_path)

        expect(estimates).to be_an(Array)
        expect(estimates).not_to be_empty
        expect(estimates.first).to include(:name, :miles_away, :estimated_date)
      end

      it "calculates estimates based on average daily steps over calendar days" do
        estimates = helper.pace_estimates(user, active_path)

        # User has ~14.2 miles, Rivendell is at 400 miles => ~385.8 miles away
        # 30,000 steps over 3 calendar days = 10,000 steps/day = ~4.73 miles/day
        # ~385.8 / 4.73 = ~81.5 days => ~82 days (ceil)
        rivendell_estimate = estimates.find { |e| e[:name] == "Rivendell" }
        expect(rivendell_estimate).to be_present
        expect(rivendell_estimate[:miles_away]).to be > 0
        expect(rivendell_estimate[:estimated_date]).to eq(Date.current + 82)
      end

      it "only includes milestones the user has not yet reached" do
        estimates = helper.pace_estimates(user, active_path)
        names = estimates.map { |e| e[:name] }

        # Shire is at 0 miles, user has 14+ miles, so Shire should not appear
        expect(names).not_to include("Shire")
      end
    end

    context "when user has gaps in step logging" do
      before do
        # User logged steps on Dec 19th, then nothing until Jan 20th
        # when they logged 100,000 steps for the whole gap period
        DailyStepEntry.record!(user: user, path: active_path, date: Date.new(2026, 12, 19), steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.new(2027, 1, 20), steps: 100_000)
        # total: 110,000 steps over 33 calendar days (Dec 19 to Jan 20 inclusive)
        user.step.update!(total_steps: 110_000)
      end

      it "averages over total calendar days not just days with entries" do
        estimates = helper.pace_estimates(user, active_path)

        # 110,000 steps / 33 calendar days = ~3,333 steps/day = ~1.578 miles/day
        # NOT 110,000 / 2 entries = 55,000 steps/day (which would be inflated)
        rivendell_estimate = estimates.find { |e| e[:name] == "Rivendell" }

        user_miles = 110_000 / Step::STEPS_PER_MILE.to_f
        miles_to_rivendell = 400 - user_miles
        avg_daily_miles = 110_000.to_f / 33 / Step::STEPS_PER_MILE
        expected_days = (miles_to_rivendell / avg_daily_miles).ceil

        expect(rivendell_estimate[:estimated_date]).to eq(Date.current + expected_days)
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

  describe "caching behavior" do
    around do |example|
      original_store = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache.clear
      Rails.cache = original_store
    end

    def captured_sql
      queries = []
      callback = ->(_n, _s, _f, _i, payload) {
        queries << payload[:sql] if payload[:sql] && payload[:name] != "SCHEMA"
      }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      queries
    end

    describe "#pace_estimates" do
      before do
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 2, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 1, steps: 10_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 10_000)
        user.step.update!(total_steps: 30_000)
      end

      it "returns identical results on consecutive calls" do
        first = helper.pace_estimates(user, active_path)
        second = helper.pace_estimates(user, active_path)

        expect(first).not_to be_empty
        expect(second).to eq(first)
      end

      it "issues no daily_step_entries SQL on a cache hit" do
        helper.pace_estimates(user, active_path)

        queries = captured_sql { helper.pace_estimates(user, active_path) }

        expect(queries.any? { |q| q.include?("daily_step_entries") }).to be false
      end

      it "recomputes after Step#add_steps invalidates the cache" do
        first = helper.pace_estimates(user, active_path)

        user.step.add_steps(50_000)
        second = helper.pace_estimates(user, active_path)

        expect(second).not_to eq(first)
      end
    end

    describe "#personal_bests" do
      before do
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 4, steps: 5_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 3, steps: 15_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 2, steps: 8_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current - 1, steps: 20_000)
        DailyStepEntry.record!(user: user, path: active_path, date: Date.current, steps: 12_000)
      end

      it "issues no daily_step_entries SQL on a cache hit" do
        helper.personal_bests(user, active_path)

        queries = captured_sql { helper.personal_bests(user, active_path) }

        expect(queries.any? { |q| q.include?("daily_step_entries") }).to be false
      end

      it "uses separate cache entries for different limits" do
        three = helper.personal_bests(user, active_path, limit: 3)
        five = helper.personal_bests(user, active_path, limit: 5)

        expect(three.length).to eq(3)
        expect(five.length).to eq(5)
      end
    end
  end
end
