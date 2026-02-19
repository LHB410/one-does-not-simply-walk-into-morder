class FitbitClient
  API_BASE = "https://api.fitbit.com".freeze

  class TokenRefreshError < StandardError; end
  class ApiError < StandardError; end

  def initialize(user)
    @user = user
  end

  def self.oauth_client
    OAuth2::Client.new(
      ENV.fetch("FITBIT_CLIENT_ID"),
      ENV.fetch("FITBIT_CLIENT_SECRET"),
      authorize_url: ENV.fetch("FITBIT_AUTH_URL"),
      token_url: ENV.fetch("FITBIT_REFRESH_URL")
    )
  end

  def self.authorize_url(redirect_uri:, state:)
    oauth_client.auth_code.authorize_url(
      redirect_uri: redirect_uri,
      scope: "activity",
      response_type: "code",
      state: state
    )
  end

  def self.exchange_code(code:, redirect_uri:)
    oauth_client.auth_code.get_token(code, redirect_uri: redirect_uri)
  end

  def fetch_steps(date = Date.current)
    refresh_token_if_needed!
    response = connection.get("/1/user/-/activities/date/#{date.strftime('%Y-%m-%d')}.json")
    JSON.parse(response.body).dig("summary", "steps").to_i
  end

  private

  def refresh_token_if_needed!
    return unless @user.fitbit_token_expires_at&.past?

    new_token = OAuth2::AccessToken.new(
      self.class.oauth_client,
      @user.fitbit_access_token,
      refresh_token: @user.fitbit_refresh_token
    ).refresh!

    @user.update!(
      fitbit_access_token: new_token.token,
      fitbit_refresh_token: new_token.refresh_token,
      fitbit_token_expires_at: Time.at(new_token.expires_at)
    )
  rescue OAuth2::Error => e
    Rails.logger.error("Fitbit token refresh failed for user #{@user.id}: #{e.message}")
    @user.update!(fitbit_access_token: nil, fitbit_refresh_token: nil,
                  fitbit_token_expires_at: nil, fitbit_uid: nil)
    raise TokenRefreshError, "Token refresh failed — user disconnected."
  end

  def connection
    @connection ||= Faraday.new(url: API_BASE) do |f|
      f.headers["Authorization"] = "Bearer #{@user.fitbit_access_token}"
      f.headers["Accept"] = "application/json"
    end
  end
end
