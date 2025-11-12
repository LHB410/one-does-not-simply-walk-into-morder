require "google/apis/sheets_v4"
require "googleauth"
require "net/http"
require "uri"
require "json"

class GoogleSheetsService
  SPREADSHEET_ID = ENV.fetch("GOOGLE_SHEET_ID")
  RANGE = "'Walk to Mordor'!A2:C" # Tab name + Email/Steps/Date (open-ended rows)
  WEBAPP_URL = ENV.fetch("GOOGLE_SHEETS_WEBAPP_URL")

  def initialize
    # Only initialize Google API client if no Web App URL is configured
    unless WEBAPP_URL.present?
      @service = Google::Apis::SheetsV4::SheetsService.new
      @service.authorization = authorize
    end
  end

  def fetch_user_steps
    # Prefer Web App endpoint if configured (no Google client auth needed)
    if WEBAPP_URL.present?
      rows = fetch_user_steps_rows
      return parse_rows(rows)
    end

    response = @service.get_spreadsheet_values(SPREADSHEET_ID, RANGE)
    parse_response(response) # Google API response
  rescue Google::Apis::Error => e
    Rails.logger.error("Google Sheets API error: #{e.message}")
    {}
  end

  # Returns raw rows from the sheet to enable job-level filtering (e.g., by date)
  # Expected row format: [email, steps, date?]
  def fetch_user_steps_rows
    # Prefer Web App endpoint if configured (no Google client auth needed)
    if WEBAPP_URL.present?
      return fetch_rows_via_webapp
    end

    response = @service.get_spreadsheet_values(SPREADSHEET_ID, RANGE)
    response.values || []
  rescue Google::Apis::Error => e
    Rails.logger.error("Google Sheets API error: #{e.message}")
    []
  end

  private

  def authorize
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(ENV["GOOGLE_SERVICE_ACCOUNT_JSON"]),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
    )
  end

  def parse_response(response)
    # Expected format: Column A = email, Column B = steps for today
    steps_data = {}

    response.values&.each do |row|
      email = row[0]&.strip&.downcase
      steps = row[1]&.to_i || 0

      steps_data[email] = steps if email.present? && steps > 0
    end

    steps_data
  end

  # Accepts either:
  # - { "values": [ [email, steps, date?], ... ] }
  # - [ [email, steps, date?], ... ]
  def fetch_rows_via_webapp
    uri = URI.parse(WEBAPP_URL)
    redirects_remaining = 5
    res = nil
    while redirects_remaining > 0
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        req["Accept"] = "application/json"
        http.request(req)
      end
      case res
      when Net::HTTPSuccess
        break
      when Net::HTTPRedirection
        location = res["location"]
        break unless location
        uri = URI.parse(location)
        redirects_remaining -= 1
        next
      else
        Rails.logger.warn("Google Sheets WebApp non-success: #{res.code} #{res.message}")
        return []
      end
    end
    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Google Sheets WebApp exhausted redirects or no success")
      return []
    end

    body = res.body
    data = JSON.parse(body) rescue nil
    return [] if data.nil?

    return Array(data["values"]) if data.is_a?(Hash) && data.key?("values")
    return data if data.is_a?(Array)
    []
  rescue StandardError => e
    Rails.logger.error("Google Sheets WebApp error: #{e.message}")
    []
  end

  # Convert array rows to { email => steps } map
  def parse_rows(rows)
    rows.each_with_object({}) do |row, acc|
      email = row[0]&.strip&.downcase
      steps = row[1].to_i
      acc[email] = steps if email.present? && steps > 0
    end
  end
end
