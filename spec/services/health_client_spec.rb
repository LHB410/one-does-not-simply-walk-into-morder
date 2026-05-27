require 'rails_helper'

RSpec.describe HealthClient do
  let(:user) do
    create(:user).tap do |u|
      u.update!(
        health_uid: "TESTUID",
        health_access_token: "valid_token",
        health_refresh_token: "refresh_token",
        health_token_expires_at: 1.hour.from_now
      )
    end
  end

  let(:client) { described_class.new(user) }

  # A dailyRollUp response: rollupDataPoints carrying steps.countSum (int64 as a string).
  let(:success_body) do
    {
      "rollupDataPoints" => [
        {
          "civilStartTime" => { "date" => { "year" => 2026, "month" => 5, "day" => 27 } },
          "steps" => { "countSum" => "8500" }
        }
      ]
    }.to_json
  end
  let(:empty_body) { { "rollupDataPoints" => [] }.to_json }
  let(:error_body) { { "error" => { "code" => 401, "status" => "UNAUTHENTICATED" } }.to_json }

  def stub_api_response(status:, body:)
    response = instance_double(Faraday::Response, status: status, body: body, success?: (200..299).cover?(status))
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:post).and_return(response)
    allow(Faraday).to receive(:new).and_return(connection)
    connection
  end

  def stub_sequential_responses(*responses)
    response_doubles = responses.map do |r|
      instance_double(Faraday::Response, status: r[:status], body: r[:body], success?: (200..299).cover?(r[:status]))
    end
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:post).and_return(*response_doubles)
    allow(Faraday).to receive(:new).and_return(connection)
    connection
  end

  def stub_token_refresh
    signet = instance_double(
      Signet::OAuth2::Client,
      access_token: "new_access_token",
      refresh_token: "new_refresh_token",
      expires_at: 1.hour.from_now
    )
    allow(signet).to receive(:refresh!).and_return(true)
    allow(HealthClient).to receive(:signet_client).and_return(signet)
    signet
  end

  describe "#fetch_steps" do
    context "with a valid token and successful response" do
      before { stub_api_response(status: 200, body: success_body) }

      it "returns the aggregated step count" do
        expect(client.fetch_steps).to eq(8500)
      end
    end

    context "when the day has no recorded steps" do
      before { stub_api_response(status: 200, body: empty_body) }

      it "returns zero" do
        expect(client.fetch_steps).to eq(0)
      end
    end

    context "when the API returns 401" do
      before { stub_token_refresh }

      it "force-refreshes the token and retries" do
        stub_sequential_responses(
          { status: 401, body: error_body },
          { status: 200, body: success_body }
        )

        expect(client.fetch_steps).to eq(8500)
      end

      it "raises ApiError if retry also fails" do
        stub_sequential_responses(
          { status: 401, body: error_body },
          { status: 401, body: error_body }
        )

        expect { client.fetch_steps }.to raise_error(HealthClient::ApiError, /HTTP 401/)
      end
    end

    context "when the API returns a non-401 error" do
      before { stub_api_response(status: 500, body: '{"error":{}}') }

      it "raises ApiError without retrying" do
        expect { client.fetch_steps }.to raise_error(HealthClient::ApiError, /HTTP 500/)
      end
    end
  end

  describe "token refresh behavior" do
    before { stub_api_response(status: 200, body: success_body) }

    context "when token expiry is in the future" do
      it "does not refresh the token" do
        expect(HealthClient).not_to receive(:signet_client)
        client.fetch_steps
      end
    end

    context "when token expiry is in the past" do
      before do
        user.update!(health_token_expires_at: 1.hour.ago)
        stub_token_refresh
      end

      it "refreshes the token" do
        client.fetch_steps
        user.reload
        expect(user.health_access_token).to eq("new_access_token")
        expect(user.health_refresh_token).to eq("new_refresh_token")
      end
    end

    context "when token expiry is nil" do
      before do
        user.update!(health_token_expires_at: nil)
        stub_token_refresh
      end

      it "refreshes the token" do
        client.fetch_steps
        user.reload
        expect(user.health_access_token).to eq("new_access_token")
      end
    end

    context "when Google omits a new refresh token on refresh" do
      before do
        user.update!(health_token_expires_at: 1.hour.ago)
        signet = instance_double(
          Signet::OAuth2::Client,
          access_token: "new_access_token",
          refresh_token: nil,
          expires_at: 1.hour.from_now
        )
        allow(signet).to receive(:refresh!).and_return(true)
        allow(HealthClient).to receive(:signet_client).and_return(signet)
      end

      it "preserves the existing refresh token" do
        client.fetch_steps
        user.reload
        expect(user.health_refresh_token).to eq("refresh_token")
      end
    end

    context "when token refresh fails" do
      before do
        user.update!(health_token_expires_at: 1.hour.ago)
        signet = instance_double(Signet::OAuth2::Client)
        allow(signet).to receive(:refresh!).and_raise(Signet::AuthorizationError.new("invalid_grant"))
        allow(HealthClient).to receive(:signet_client).and_return(signet)
      end

      it "raises TokenRefreshError" do
        expect { client.fetch_steps }.to raise_error(HealthClient::TokenRefreshError)
      end

      it "clears access tokens" do
        begin; client.fetch_steps; rescue HealthClient::TokenRefreshError; end
        user.reload
        expect(user.health_access_token).to be_nil
        expect(user.health_refresh_token).to be_nil
        expect(user.health_token_expires_at).to be_nil
      end

      it "preserves health_uid so the user can reconnect" do
        begin; client.fetch_steps; rescue HealthClient::TokenRefreshError; end
        user.reload
        expect(user.health_uid).to eq("TESTUID")
      end
    end
  end

  describe ".authorize_url" do
    it "builds a Google consent URL requesting offline access" do
      url = described_class.authorize_url(redirect_uri: "https://example.com/auth/health/callback", state: "xyz")

      expect(url).to start_with("https://accounts.google.com/o/oauth2/v2/auth")
      expect(url).to include("access_type=offline")
      expect(url).to include("state=xyz")
      expect(url).to include("googlehealth.activity_and_fitness.readonly")
    end
  end

  describe ".fetch_identity" do
    it "returns the health user id from the identity endpoint" do
      identity = { "name" => "users/me/identity", "legacyUserId" => "C9WFGD", "healthUserId" => "429903135594184479" }
      response = instance_double(Faraday::Response, status: 200, success?: true, body: identity.to_json)
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get).with("/v4/users/me/identity").and_return(response)
      allow(Faraday).to receive(:new).and_return(connection)

      expect(described_class.fetch_identity(access_token: "tok")).to eq("429903135594184479")
    end

    it "raises ApiError when the identity call fails" do
      response = instance_double(Faraday::Response, status: 403, success?: false, body: "forbidden")
      connection = instance_double(Faraday::Connection)
      allow(connection).to receive(:get).and_return(response)
      allow(Faraday).to receive(:new).and_return(connection)

      expect { described_class.fetch_identity(access_token: "tok") }.to raise_error(HealthClient::ApiError, /HTTP 403/)
    end
  end
end
