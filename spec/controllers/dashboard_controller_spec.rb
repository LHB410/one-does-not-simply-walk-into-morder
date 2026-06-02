require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  describe "GET #index" do
    context "when logged in" do
      include_context "authenticated user"
      include_context "active path with milestones"

      it "loads users and active path" do
        # Ensure Path.current returns the active_path we created
        allow(Path).to receive(:current).and_return(active_path)
        get :index

        expect(assigns(:users)).to be_present
        expect(assigns(:active_path)).to eq(active_path)
        expect(assigns(:current_user)).to eq(user)
      end

      it "renders successfully" do
        get :index

        expect(response).to have_http_status(:success)
      end
    end

    context "when logged out" do
      render_views
      before { session[:user_id] = nil }

      it "presents the sign up and log in choices" do
        get :index

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Sign up")
        expect(response.body).to include("Log in")
        expect(response.body).to include(sign_up_path)
      end
    end
  end
end
