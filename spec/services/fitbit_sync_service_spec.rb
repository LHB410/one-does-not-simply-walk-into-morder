require 'rails_helper'

RSpec.describe FitbitSyncService do
  include_context "user with path progress"

  let(:service) { described_class.new(user) }

  before do
    user.update!(fitbit_uid: "TESTUID", fitbit_access_token: "token123")
    # Path.clear_current_cache! sets @current_path = nil, but defined?(@current_path)
    # still returns true, so Path.current returns nil without querying the DB.
    # Remove the variable entirely so Path.current re-queries and finds our active_path.
    Path.remove_instance_variable(:@current_path) if Path.instance_variable_defined?(:@current_path)
  end

  def stub_fitbit_steps(steps)
    allow_any_instance_of(FitbitClient).to receive(:fetch_steps).and_return(steps)
  end

  describe "#call" do
    context "when user has no prior steps" do
      before { stub_fitbit_steps(8000) }

      it "records the full Fitbit step count" do
        expect { service.call }.to change { user.step.reload.total_steps }.by(8000)
      end

      it "sets steps_today to the Fitbit total" do
        service.call
        expect(user.step.reload.steps_today).to eq(8000)
      end

      it "creates a daily step entry" do
        expect { service.call }.to change { DailyStepEntry.count }.by(1)

        entry = DailyStepEntry.last
        expect(entry.steps).to eq(8000)
        expect(entry.date).to eq(Date.current)
      end

      it "updates path progress" do
        service.call
        expect(path_user.reload.progress_percentage).to be > 0
      end

      it "sets fitbit_last_sync_at" do
        expect { service.call }.to change { user.reload.fitbit_last_sync_at }.from(nil)
      end

      it "returns true" do
        expect(service.call).to be true
      end
    end

    context "when user already entered steps manually today" do
      before do
        user.step.add_steps(3000, force: true)
        path_user.update_progress(active_path)
        stub_fitbit_steps(8000)
      end

      it "only adds the delta, not the full Fitbit count" do
        expect { service.call }.to change { user.step.reload.total_steps }.by(5000)
      end

      it "sets steps_today to the Fitbit total" do
        service.call
        expect(user.step.reload.steps_today).to eq(8000)
      end

      it "replaces the daily entry with the Fitbit total" do
        expect { service.call }.not_to change { DailyStepEntry.count }

        entry = DailyStepEntry.find_by(user: user, path: active_path, date: Date.current)
        expect(entry.steps).to eq(8000)
      end

      it "preserves correct total (previous days + Fitbit today)" do
        total_before = user.step.reload.total_steps
        service.call
        expect(user.step.reload.total_steps).to eq(total_before - 3000 + 8000)
      end

      it "does not reduce progress percentage" do
        progress_before = path_user.reload.progress_percentage
        service.call
        expect(path_user.reload.progress_percentage).to be >= progress_before
      end
    end

    context "when Fitbit has fewer steps than manually entered" do
      before do
        user.step.add_steps(10_000, force: true)
        path_user.update_progress(active_path)
        stub_fitbit_steps(5000)
      end

      it "does not reduce total steps" do
        expect { service.call }.not_to change { user.step.reload.total_steps }
      end

      it "does not modify the daily entry" do
        entry = DailyStepEntry.find_by(user: user, path: active_path, date: Date.current)
        expect { service.call }.not_to change { entry.reload.steps }
      end

      it "does not reduce progress" do
        expect { service.call }.not_to change { path_user.reload.progress_percentage }
      end

      it "still returns true and sets last sync" do
        service.call
        expect(user.reload.fitbit_last_sync_at).to be_present
      end
    end

    context "when Fitbit returns zero steps" do
      before { stub_fitbit_steps(0) }

      it "does nothing and returns true" do
        expect { service.call }.not_to change { user.step.reload.total_steps }
        expect(service.call).to be true
      end
    end

    context "when user is not connected to Fitbit" do
      before { user.update!(fitbit_uid: nil) }

      it "returns false without calling the API" do
        expect_any_instance_of(FitbitClient).not_to receive(:fetch_steps)
        expect(service.call).to be false
      end
    end

    context "when there is no active path" do
      before do
        active_path.update!(active: false)
        Path.clear_current_cache!
        stub_fitbit_steps(8000)
      end

      it "returns false" do
        expect(service.call).to be false
      end
    end

    context "when the Fitbit token has expired" do
      before do
        allow_any_instance_of(FitbitClient).to receive(:fetch_steps)
          .and_raise(FitbitClient::TokenRefreshError, "Token expired")
      end

      it "returns false and does not crash" do
        expect(service.call).to be false
        expect(user.step.reload.total_steps).to eq(0)
      end
    end

    context "when the Fitbit API returns an error" do
      before do
        allow_any_instance_of(FitbitClient).to receive(:fetch_steps)
          .and_raise(FitbitClient::ApiError, "API error")
      end

      it "returns false and does not modify steps" do
        expect(service.call).to be false
        expect(user.step.reload.total_steps).to eq(0)
      end
    end
  end
end
