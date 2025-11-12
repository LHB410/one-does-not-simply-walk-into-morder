require 'rails_helper'

RSpec.describe DailyStepUpdateJob, type: :job do
  include_context "active path with milestones"

  let!(:user1) { create(:user, email: 'frodo@shire.me') }
  let!(:user2) { create(:user, email: 'sam@shire.me') }
  let!(:path_user1) { create(:path_user, user: user1, path: active_path) }
  let!(:path_user2) { create(:path_user, user: user2, path: active_path) }

  let(:sheets_service) { instance_double(GoogleSheetsService) }
  let(:rows_today) do
    [
      [ 'frodo@shire.me', '5000', Date.current.in_time_zone('America/Chicago').to_s ],
      [ 'sam@shire.me', '6200', Date.current.in_time_zone('America/Chicago').to_s ]
    ]
  end

  before do
    allow(GoogleSheetsService).to receive(:new).and_return(sheets_service)
    allow(sheets_service).to receive(:fetch_user_steps_rows).and_return(rows_today)
  end

  describe "#perform" do
    before do
      allow_any_instance_of(User).to receive(:total_miles).and_return(2)
    end
    it "fetches data from Google Sheets" do
      expect(sheets_service).to receive(:fetch_user_steps_rows)

      described_class.perform_now
    end

    context "when sheet rows are stale (not today)" do
      it "skips updates for all users" do
        stale_rows = [
          [ 'frodo@shire.me', '5000', (Date.current - 1).to_s ],
          [ 'sam@shire.me', '6200', (Date.current - 1).to_s ]
        ]
        allow(sheets_service).to receive(:fetch_user_steps_rows).and_return(stale_rows)
        expect {
          described_class.perform_now
        }.not_to change { user1.step.reload.total_steps }

        expect {
          described_class.perform_now
        }.not_to change { user2.step.reload.total_steps }
      end
    end

    it "updates all users steps" do
      described_class.perform_now

      expect(user1.step.reload.total_steps).to eq(5000)
      expect(user2.step.reload.total_steps).to eq(6200)
    end

    it "updates path progress for all users" do
      described_class.perform_now

      expect(path_user1.reload.progress_percentage).to be > 0
      expect(path_user2.reload.progress_percentage).to be > 0
    end

    it "sets last_updated_date to current date" do
      described_class.perform_now

      expect(user1.step.reload.last_updated_date).to eq(Date.current)
      expect(user2.step.reload.last_updated_date).to eq(Date.current)
    end

    context "when steps already updated today" do
      before do
        user1.step.update(last_updated_date: Date.current)
      end

      it "skips that user" do
        expect {
          described_class.perform_now
        }.not_to change { user1.step.reload.total_steps }
      end

      it "still updates other users" do
        expect {
          described_class.perform_now
        }.to change { user2.step.reload.total_steps }
      end
    end

    context "when no data retrieved" do
      before do
        allow(sheets_service).to receive(:fetch_user_steps_rows).and_return([])
      end

      it "logs warning and exits early" do
        expect(Rails.logger).to receive(:warn).with(/No step data/)

        described_class.perform_now
      end
    end

    context "when all users complete part 1" do
      let!(:part_two) { create(:path, :part_two) }

      before do
        path_user1.update(progress_percentage: 100.0)
        path_user2.update(progress_percentage: 100.0)
        allow_any_instance_of(Path).to receive(:all_users_completed?).and_return(true)
      end

      it "transitions to part 2" do
        described_class.perform_now

        expect(active_path.reload.active).to be false
        expect(part_two.reload.active).to be true
      end
    end
  end
end
