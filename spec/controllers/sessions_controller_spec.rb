require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:user) { create(:user, email: 'frodo@shire.me', password: 'password123') }

  describe "POST #create" do
    context "with valid credentials" do
      it "logs in the user" do
        post :create, params: { session: { email: user.email, password: 'password123' } }

        expect(session[:user_id]).to eq(user.id)
      end

      it "redirects to root path" do
        post :create, params: { session: { email: user.email, password: 'password123' } }

        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid credentials" do
      before { session[:user_id] = nil }
      it "does not log in the user" do
        post :create, params: { session: { email: user.email, password: 'wrongpassword' } }

        expect(session[:user_id]).to be_nil
      end

      it "redirects to root with alert" do
        post :create, params: { session: { email: user.email, password: 'wrongpassword' } }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE #destroy" do
    before { session[:user_id] = user.id }

    it "logs out the user" do
      delete :destroy

      expect(session[:user_id]).to be_nil
    end

    it "redirects to root path" do
      delete :destroy

      expect(response).to redirect_to(root_path)
    end
  end
end


