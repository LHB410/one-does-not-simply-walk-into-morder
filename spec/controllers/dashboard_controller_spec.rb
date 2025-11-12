require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  describe "GET #index" do
    context "when logged in" do
      include_context "authenticated user"
      include_context "active path with milestones"

      it "loads users and active path" do
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
  end
end
