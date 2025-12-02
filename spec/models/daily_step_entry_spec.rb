require "rails_helper"

RSpec.describe DailyStepEntry, type: :model do
  include_context "user with path progress"

  describe ".record!" do
    it "creates or updates a daily entry for the user and path" do
      date = Date.current

      expect {
        described_class.record!(user: user, path: active_path, date: date, steps: 1000)
      }.to change { described_class.count }.by(1)

      expect {
        described_class.record!(user: user, path: active_path, date: date, steps: 500)
      }.not_to change { described_class.count }

      entry = described_class.last
      expect(entry.steps).to eq(1500)
    end
  end

  describe ".daily_totals_for" do
    before do
      described_class.record!(user: user, path: active_path, date: Date.current - 1, steps: 1000)
      described_class.record!(user: user, path: active_path, date: Date.current, steps: 2000)
    end

    it "returns grouped totals ordered by date desc with pagination" do
      results = described_class.daily_totals_for(
        user: user,
        path: active_path,
        page: 1,
        per_page: 1
      )

      expect(results.length).to eq(1)
      expect(results.first.date).to eq(Date.current)
      expect(results.first.total_steps.to_i).to eq(2000)
    end
  end

  describe ".total_days_for" do
    it "returns the number of distinct days with entries" do
      described_class.record!(user: user, path: active_path, date: Date.current - 1, steps: 1000)
      described_class.record!(user: user, path: active_path, date: Date.current, steps: 2000)

      expect(described_class.total_days_for(user: user, path: active_path)).to eq(2)
    end
  end
end
