require 'rails_helper'

# Session must expire on inactivity (idle) and at a hard ceiling (absolute),
# regardless of activity. ASVS V3 / SECURITY_AUDIT P4.
RSpec.describe "Session timeout", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include_context "user with path progress"

  let(:password) { 'password123' }
  let(:user) { create(:user, email: 'frodo@shire.me', password: password) }

  before do
    # Path.current is memoized at the class level; pin it to the test's active path.
    allow(Path).to receive(:current).and_return(active_path)
  end

  def log_in
    post login_path, params: { session: { email: user.email, password: password } }
  end

  describe "idle timeout (2h)" do
    it "stays logged in while active within the idle window" do
      log_in

      travel(1.hour + 50.minutes) { get root_path }

      expect(session[:user_id]).to eq(user.id)
    end

    it "logs the user out after 2h of inactivity" do
      log_in

      travel(2.hours + 1.minute) { get root_path }

      expect(session[:user_id]).to be_nil
    end

    it "redirects an expired session to the homepage with an alert" do
      log_in

      travel(2.hours + 1.minute) { get root_path }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/session/i)
    end

    it "slides the idle window forward on each request" do
      log_in

      travel(1.hour + 30.minutes) { get root_path } # activity at +90m resets the idle clock
      travel(3.hours) { get root_path }              # +180m from login, but only 90m since activity

      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe "absolute timeout (24h)" do
    it "logs the user out after 24h even with continuous activity" do
      log_in

      travel(23.hours + 50.minutes) { get root_path } # still active, within the absolute cap
      travel(24.hours + 1.minute) { get root_path }    # idle clock fine, but absolute cap exceeded

      expect(session[:user_id]).to be_nil
    end
  end
end
