require 'rails_helper'

RSpec.describe PagesController, type: :controller do
  render_views

  # These pages are public — reachable without logging in.
  before { session[:user_id] = nil }

  describe "GET #privacy" do
    it "renders the privacy policy successfully" do
      get :privacy

      expect(response).to have_http_status(:ok)
      expect(response).to render_template("pages/privacy")
    end

    it "includes the Google API Limited Use disclosure" do
      get :privacy

      expect(response.body).to include("Google API Services User Data Policy")
      expect(response.body).to match(/Limited Use/i)
    end
  end

  describe "GET #terms" do
    it "renders the terms of service successfully" do
      get :terms

      expect(response).to have_http_status(:ok)
      expect(response).to render_template("pages/terms")
    end
  end
end
