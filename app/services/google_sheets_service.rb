require "google/apis/sheets_v4"
require "googleauth"

class GoogleSheetsService
  SPREADSHEET_ID = ENV["GOOGLE_SHEET_ID"]
  RANGE = "Sheet1!A2:B5" # Adjust based on your sheet structure

  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end

  def fetch_user_steps
    response = @service.get_spreadsheet_values(SPREADSHEET_ID, RANGE)
    parse_response(response)
  rescue Google::Apis::Error => e
    Rails.logger.error("Google Sheets API error: #{e.message}")
    {}
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
end
