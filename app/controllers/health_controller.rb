class HealthController < ApplicationController
  before_action :require_login

  def connect
    state = SecureRandom.hex(16)
    session[:health_oauth_state] = state
    session[:health_timezone] = params[:timezone]

    redirect_to HealthClient.authorize_url(
      redirect_uri: health_callback_url,
      state: state
    ), allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:health_oauth_state)
      return redirect_to root_path, alert: "Invalid OAuth state"
    end

    token = HealthClient.exchange_code(code: params[:code], redirect_uri: health_callback_url)

    current_user.update!(
      health_uid: HealthClient.fetch_identity(access_token: token.access_token),
      health_access_token: token.access_token,
      health_refresh_token: token.refresh_token,
      health_token_expires_at: token.expires_at,
      timezone: session.delete(:health_timezone)
    )

    HealthSyncJob.schedule_for(current_user)

    redirect_to root_path, notice: "Google Health connected!"
  rescue Signet::AuthorizationError, HealthClient::ApiError => e
    log(:error, "Google Health OAuth failed: #{e.message}")
    redirect_to root_path, alert: "Failed to connect Google Health"
  end

  def disconnect
    HealthClient.revoke_token(current_user.health_refresh_token || current_user.health_access_token)

    current_user.update!(
      health_uid: nil,
      health_access_token: nil,
      health_refresh_token: nil,
      health_token_expires_at: nil,
      health_last_sync_at: nil
    )

    redirect_to root_path, notice: "Google Health disconnected"
  end
end
