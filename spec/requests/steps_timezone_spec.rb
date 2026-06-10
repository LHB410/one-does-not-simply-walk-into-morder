require "rails_helper"

# Manual step entries must be dated in the *acting user's* timezone, not the
# server's UTC day. The zone is resolved user-first: the saved value wins, a
# browser-supplied `timezone` param bootstraps users who have none (and is
# persisted so later requests use the stored value), and anything unrecognised
# falls back to the app default — a hostile param can never raise or hit the DB.
RSpec.describe "Manual step update timezone", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:active_path) { create(:path, :active) }

  # 02:55 UTC on Jun 10 is still 10:55 PM EDT on Jun 9 — the user's "today" is
  # the 9th, so that is the date an Eastern user's entry must carry.
  let(:late_evening_utc) { Time.utc(2026, 6, 10, 2, 55) }

  before do
    # Path.current is memoized at the class level; stubbing the memoized lookup
    # is the one boundary the repo permits mocking.
    allow(Path).to receive(:current).and_return(active_path)
  end

  def login(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  context "when the user has a saved timezone" do
    let(:user) { create(:user, timezone: "America/New_York") }
    before { login(user) }

    it "dates the entry by the user's local date, not the server's UTC date" do
      travel_to(late_evening_utc) { patch step_path(user.step), params: { steps: 2200 } }

      entry = DailyStepEntry.find_by(user: user, path: active_path)
      expect(entry.date).to eq(Date.new(2026, 6, 9))
    end
  end

  context "when the user has no saved timezone but the browser sends one" do
    let(:user) { create(:user, timezone: nil) }
    before { login(user) }

    it "dates the entry by the submitted browser zone and persists it to the user" do
      travel_to(late_evening_utc) do
        patch step_path(user.step), params: { steps: 2200, timezone: "America/New_York" }
      end

      entry = DailyStepEntry.find_by(user: user, path: active_path)
      expect(entry.date).to eq(Date.new(2026, 6, 9))
      expect(user.reload.timezone).to eq("America/New_York")
    end
  end

  context "when the submitted timezone is hostile / invalid" do
    let(:user) { create(:user, timezone: nil) }
    before { login(user) }

    it "ignores it safely: no error, nothing persisted, dated by the UTC fallback" do
      malicious = "x'); DROP TABLE users; --"

      expect {
        travel_to(late_evening_utc) do
          patch step_path(user.step), params: { steps: 2200, timezone: malicious }
        end
      }.not_to change(User, :count)

      entry = DailyStepEntry.find_by(user: user, path: active_path)
      expect(entry.date).to eq(Date.new(2026, 6, 10)) # UTC fallback, unchanged behaviour
      expect(user.reload.timezone).to be_nil
    end
  end
end
