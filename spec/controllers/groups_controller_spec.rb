require 'rails_helper'

RSpec.describe GroupsController, type: :controller do
  let(:group) { create(:group, password: "old-password", password_confirmation: "old-password") }
  let(:leader) { create(:user, :group_member, group: group) }
  let(:member) { create(:user, :group_member, group: group) }

  before { group.update!(leader: leader) }

  def change_password_to(password, confirmation = password)
    patch :update_password, params: { group: { password: password, password_confirmation: confirmation } }
  end

  describe "PATCH #update_password" do
    context "as the group leader" do
      before { session[:user_id] = leader.id }

      it "updates the shared group password" do
        change_password_to("new-password")

        expect(group.reload.authenticate("new-password")).to eq(group)
      end

      it "redirects to root" do
        change_password_to("new-password")

        expect(response).to redirect_to(root_path)
      end

      it "leaves the password unchanged when the confirmation does not match" do
        change_password_to("new-password", "does-not-match")

        expect(group.reload.authenticate("old-password")).to eq(group)
      end
    end

    context "as a non-leader member" do
      before { session[:user_id] = member.id }

      it "is forbidden" do
        change_password_to("new-password")

        expect(response).to have_http_status(:forbidden)
      end

      it "does not change the password" do
        change_password_to("new-password")

        expect(group.reload.authenticate("old-password")).to eq(group)
      end
    end

    context "when logged out" do
      before { session[:user_id] = nil }

      it "redirects to root and does not change the password" do
        change_password_to("new-password")

        expect(response).to redirect_to(root_path)
        expect(group.reload.authenticate("old-password")).to eq(group)
      end
    end
  end
end
