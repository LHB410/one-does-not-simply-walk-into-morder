require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  include_context "authenticated user"

  describe "DELETE #disconnect" do
    before do
      user.update!(
        health_uid: "TESTUID",
        health_access_token: "access",
        health_refresh_token: "refresh",
        health_token_expires_at: 1.hour.from_now,
        health_last_sync_at: Time.current
      )
    end

    context "when revocation succeeds" do
      before { allow(HealthClient).to receive(:revoke_token).and_return(true) }

      it "revokes the grant with Google using the refresh token" do
        delete :disconnect

        expect(HealthClient).to have_received(:revoke_token).with("refresh")
      end

      it "clears every stored Google Health credential" do
        delete :disconnect
        user.reload

        expect(user.health_uid).to be_nil
        expect(user.health_access_token).to be_nil
        expect(user.health_refresh_token).to be_nil
        expect(user.health_token_expires_at).to be_nil
        expect(user.health_last_sync_at).to be_nil
      end
    end

    context "when revocation fails" do
      before { allow(HealthClient).to receive(:revoke_token).and_return(false) }

      it "still clears the stored tokens so the local disconnect always completes" do
        delete :disconnect
        user.reload

        expect(user.health_access_token).to be_nil
        expect(user.health_refresh_token).to be_nil
      end
    end
  end
end
