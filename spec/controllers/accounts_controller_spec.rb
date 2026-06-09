require 'rails_helper'

RSpec.describe AccountsController, type: :controller do
  describe "PATCH #update" do
    context "when logged in" do
      include_context "authenticated user"

      it "updates the user's name and redirects with a notice" do
        patch :update, params: { user: { name: "Aragorn" } }

        expect(user.reload.name).to eq("Aragorn")
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_present
      end

      it "rejects a blank name and leaves it unchanged" do
        original = user.name

        patch :update, params: { user: { name: "" } }

        expect(user.reload.name).to eq(original)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when not logged in" do
      before { session[:user_id] = nil }

      it "redirects to root without updating" do
        patch :update, params: { user: { name: "Sauron" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE #destroy" do
    context "when logged in" do
      include_context "authenticated user"

      it "closes the account via AccountClosure" do
        closure = instance_double(AccountClosure, call: true)
        allow(AccountClosure).to receive(:new).with(user).and_return(closure)

        delete :destroy

        expect(closure).to have_received(:call)
      end

      it "deletes the user and their data" do
        delete :destroy
        expect(User.exists?(user.id)).to be(false)
      end

      it "clears the session" do
        delete :destroy
        expect(session[:user_id]).to be_nil
      end

      it "redirects to root with a confirmation notice" do
        delete :destroy
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "when not logged in" do
      before { session[:user_id] = nil }

      it "redirects to root and does not close any account" do
        expect(AccountClosure).not_to receive(:new)

        delete :destroy

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
