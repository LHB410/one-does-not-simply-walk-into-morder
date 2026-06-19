require 'rails_helper'

# Static pages must not answer arbitrary format extensions, so probes like
# /privacy.bak don't return 200 and trip ZAP's Backup File Disclosure rule.
RSpec.describe "Static page format handling", type: :request do
  it "serves the privacy page" do
    get "/privacy"
    expect(response).to have_http_status(:ok)
  end

  it "does not serve fake backup-file extensions on privacy" do
    get "/privacy.bak"
    expect(response).to have_http_status(:not_found)
  end

  it "does not serve fake backup-file extensions on sign_up" do
    get "/sign_up.old"
    expect(response).to have_http_status(:not_found)
  end

  it "does not serve fake backup-file extensions on terms" do
    get "/terms.backup"
    expect(response).to have_http_status(:not_found)
  end
end
