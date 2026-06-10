require "rails_helper"

# Regression: a manual step update must be dated by the *acting user's* local
# date, not the server's UTC date. Austin (America/New_York) logged steps at
# ~10:55 PM Eastern on Jun 9 — already Jun 10 in UTC — and the entry was
# mis-dated to Jun 10 because Step#add_steps reads Date.current (UTC) and no
# per-request Time.zone is set. The job path already uses the user's zone.
RSpec.describe "Manual step update timezone", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:active_path) { create(:path, :active) }
  let(:user) { create(:user, timezone: "America/New_York") }

  before do
    # Path.current is memoized at the class level; stubbing the memoized lookup
    # is the one boundary the repo permits mocking.
    allow(Path).to receive(:current).and_return(active_path)
    post login_path, params: { email: user.email, password: "password123" }
  end

  it "dates the entry by the user's local date, not the server's UTC date" do
    # 02:55 UTC on Jun 10 is still 10:55 PM EDT on Jun 9 — the user's "today"
    # is the 9th, so that is the date the entry must carry.
    travel_to Time.utc(2026, 6, 10, 2, 55) do
      patch step_path(user.step), params: { steps: 2200 }
    end

    entry = DailyStepEntry.find_by(user: user, path: active_path)
    expect(entry).to be_present
    expect(entry.date).to eq(Date.new(2026, 6, 9))
  end
end
