require "rails_helper"

# Rack::Attack runs as middleware, so these must be request specs (controller
# specs bypass the middleware stack).
RSpec.describe "Rate limiting", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after { Rack::Attack.cache.store.clear }

  def attempt_login
    post login_path, params: { session: { email: "intruder@shire.me", password: "guess" } }
  end

  it "throttles repeated login attempts from the same IP" do
    11.times { attempt_login }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "allows a normal number of login attempts" do
    3.times { attempt_login }

    expect(response).not_to have_http_status(:too_many_requests)
  end
end
