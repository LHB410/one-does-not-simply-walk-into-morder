require 'rails_helper'

RSpec.describe GoogleSheetsService do
  let(:service) { described_class.new }
  let(:mock_service) { instance_double(Google::Apis::SheetsV4::SheetsService) }
  let(:fixture_values) do
    path = Rails.root.join('spec/fixtures/files/google_sheets_values.json')
    JSON.parse(File.read(path))['values']
  end
  let(:mock_response) { double(values: fixture_values) }

  before do
    allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:authorization=)
    allow_any_instance_of(described_class).to receive(:authorize).and_return(double)
  end

  describe "#fetch_user_steps" do
    context "with valid response" do
      before do
        allow(mock_service).to receive(:get_spreadsheet_values).and_return(mock_response)
      end

      it "returns parsed steps data" do
        result = service.fetch_user_steps

        expect(result).to eq({
          'frodo@shire.me' => 5000,
          'sam@shire.me' => 6200,
          'pippin@shire.me' => 4800
        })
      end

      it "normalizes email addresses" do
        result = service.fetch_user_steps

        expect(result.keys).to all(match(/^[a-z@.]+$/))
      end

      it "filters out invalid step counts" do
        result = service.fetch_user_steps

        expect(result).not_to have_key('invalid@example.com')
      end
    end

    context "when API error occurs" do
      before do
        allow(mock_service).to receive(:get_spreadsheet_values)
          .and_raise(Google::Apis::Error.new("API Error"))
      end

      it "logs error and returns empty hash" do
        expect(Rails.logger).to receive(:error).with(/Google Sheets API error/)

        result = service.fetch_user_steps

        expect(result).to eq({})
      end
    end
  end
end
