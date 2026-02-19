class FitbitController < ApplicationController
  before_action :require_login

  def connect
    state = SecureRandom.hex(16)
    session[:fitbit_oauth_state] = state
    session[:fitbit_timezone] = params[:timezone]

    redirect_to FitbitClient.authorize_url(
      redirect_uri: fitbit_callback_url,
      state: state
    ), allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:fitbit_oauth_state)
      return redirect_to root_path, alert: "Invalid OAuth state"
    end

    token = FitbitClient.exchange_code(code: params[:code], redirect_uri: fitbit_callback_url)

    current_user.update!(
      fitbit_uid: token.params["user_id"],
      fitbit_access_token: token.token,
      fitbit_refresh_token: token.refresh_token,
      fitbit_token_expires_at: Time.at(token.expires_at),
      timezone: session.delete(:fitbit_timezone)
    )

    FitbitSyncJob.schedule_for(current_user)

    redirect_to root_path, notice: "Fitbit connected!"
  rescue OAuth2::Error => e
    Rails.logger.error("Fitbit OAuth failed: #{e.message}")
    redirect_to root_path, alert: "Failed to connect Fitbit"
  end

  def disconnect
    current_user.update!(
      fitbit_uid: nil,
      fitbit_access_token: nil,
      fitbit_refresh_token: nil,
      fitbit_token_expires_at: nil,
      fitbit_last_sync_at: nil
    )

    redirect_to root_path, notice: "Fitbit disconnected"
  end
end
