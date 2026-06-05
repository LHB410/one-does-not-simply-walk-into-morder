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

      it "regenerates the session to prevent session fixation" do
        # A value planted in the pre-login session must not survive authentication.
        session[:pre_login_marker] = "planted"

        post :create, params: { session: { email: user.email, password: 'password123' } }

        expect(session[:pre_login_marker]).to be_nil
        expect(session[:user_id]).to eq(user.id)
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

    context "for a group member" do
      let(:group) { create(:group, password: 'speak-friend', password_confirmation: 'speak-friend') }
      let(:member) { create(:user, :group_member, group: group, email: 'samwise@shire.me') }

      before { session[:user_id] = nil }

      it "logs in with the group's shared password" do
        post :create, params: { session: { email: member.email, password: 'speak-friend' } }

        expect(session[:user_id]).to eq(member.id)
      end

      it "does not log in with an incorrect group password" do
        post :create, params: { session: { email: member.email, password: 'orc-speak' } }

        expect(session[:user_id]).to be_nil
      end

      it "does not authenticate against an individual password (members have none)" do
        post :create, params: { session: { email: member.email, password: 'password123' } }

        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe "DELETE #destroy" do
    before { session[:user_id] = user.id }

    it "logs out the user" do
      delete :destroy

      expect(session[:user_id]).to be_nil
    end

    it "clears the entire session, not just the user id" do
      session[:health_oauth_state] = "leftover"

      delete :destroy

      expect(session[:health_oauth_state]).to be_nil
    end

    it "redirects to root path" do
      delete :destroy

      expect(response).to redirect_to(root_path)
    end
  end
end
