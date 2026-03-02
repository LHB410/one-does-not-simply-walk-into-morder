require 'rails_helper'
require 'ostruct'

RSpec.describe FitbitClient do
  let(:user) do
    create(:user).tap do |u|
      u.update!(
        fitbit_uid: "TESTUID",
        fitbit_access_token: "valid_token",
        fitbit_refresh_token: "refresh_token",
        fitbit_token_expires_at: 1.hour.from_now
      )
    end
  end

  let(:client) { described_class.new(user) }

  let(:success_body) { { "summary" => { "steps" => 8500 } }.to_json }
  let(:error_body) { { "errors" => [{ "errorType" => "expired_token" }] }.to_json }

  def stub_api_response(status:, body:)
    response = instance_double(Faraday::Response, status: status, body: body, success?: (200..299).cover?(status))
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get).and_return(response)
    allow(Faraday).to receive(:new).and_return(connection)
    connection
  end

  def stub_sequential_responses(*responses)
    response_doubles = responses.map do |r|
      instance_double(Faraday::Response, status: r[:status], body: r[:body], success?: (200..299).cover?(r[:status]))
    end
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get).and_return(*response_doubles)
    allow(Faraday).to receive(:new).and_return(connection)
    connection
  end

  def stub_token_refresh
    new_token = instance_double(
      OAuth2::AccessToken,
      token: "new_access_token",
      refresh_token: "new_refresh_token",
      expires_at: 1.hour.from_now.to_i
    )
    access_token = instance_double(OAuth2::AccessToken)
    allow(access_token).to receive(:refresh!).and_return(new_token)
    allow(OAuth2::AccessToken).to receive(:new).and_return(access_token)
    new_token
  end

  describe "#fetch_steps" do
    context "with a valid token and successful response" do
      before { stub_api_response(status: 200, body: success_body) }

      it "returns the step count" do
        expect(client.fetch_steps).to eq(8500)
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

        expect { client.fetch_steps }.to raise_error(FitbitClient::ApiError, /HTTP 401/)
      end
    end

    context "when the API returns a non-401 error" do
      before { stub_api_response(status: 500, body: '{"errors":[]}') }

      it "raises ApiError without retrying" do
        expect { client.fetch_steps }.to raise_error(FitbitClient::ApiError, /HTTP 500/)
      end
    end

    context "when the response body is missing steps" do
      before { stub_api_response(status: 200, body: { "summary" => {} }.to_json) }

      it "raises ApiError" do
        expect { client.fetch_steps }.to raise_error(FitbitClient::ApiError, /missing.*steps/i)
      end
    end

    context "when the response body has unexpected structure" do
      before { stub_api_response(status: 200, body: { "activities" => [] }.to_json) }

      it "raises ApiError" do
        expect { client.fetch_steps }.to raise_error(FitbitClient::ApiError, /missing.*steps/i)
      end
    end
  end

  describe "token refresh behavior" do
    before { stub_api_response(status: 200, body: success_body) }

    context "when token expiry is in the future" do
      it "does not refresh the token" do
        expect(OAuth2::AccessToken).not_to receive(:new)
        client.fetch_steps
      end
    end

    context "when token expiry is in the past" do
      before do
        user.update!(fitbit_token_expires_at: 1.hour.ago)
        stub_token_refresh
      end

      it "refreshes the token" do
        client.fetch_steps
        user.reload
        expect(user.fitbit_access_token).to eq("new_access_token")
        expect(user.fitbit_refresh_token).to eq("new_refresh_token")
      end
    end

    context "when token expiry is nil" do
      before do
        user.update!(fitbit_token_expires_at: nil)
        stub_token_refresh
      end

      it "refreshes the token" do
        client.fetch_steps
        user.reload
        expect(user.fitbit_access_token).to eq("new_access_token")
      end
    end

    context "when token refresh fails with OAuth2 error" do
      before do
        user.update!(fitbit_token_expires_at: 1.hour.ago)
        access_token = instance_double(OAuth2::AccessToken)
        allow(access_token).to receive(:refresh!).and_raise(OAuth2::Error.new(OpenStruct.new(body: "invalid_grant")))
        allow(OAuth2::AccessToken).to receive(:new).and_return(access_token)
      end

      it "raises TokenRefreshError" do
        expect { client.fetch_steps }.to raise_error(FitbitClient::TokenRefreshError)
      end

      it "clears access tokens" do
        begin; client.fetch_steps; rescue FitbitClient::TokenRefreshError; end
        user.reload
        expect(user.fitbit_access_token).to be_nil
        expect(user.fitbit_refresh_token).to be_nil
        expect(user.fitbit_token_expires_at).to be_nil
      end

      it "preserves fitbit_uid so the user can reconnect" do
        begin; client.fetch_steps; rescue FitbitClient::TokenRefreshError; end
        user.reload
        expect(user.fitbit_uid).to eq("TESTUID")
      end
    end
  end
end
