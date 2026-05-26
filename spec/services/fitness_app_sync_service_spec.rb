require 'rails_helper'

RSpec.describe FitnessAppSyncService do
  include_context "user with path progress"

  let(:service) { described_class.new(user) }

  before do
    user.update!(fitness_app_provider: "fitbit", fitness_app_uid: "TESTUID", fitness_app_access_token: "token123")
    # Path.clear_current_cache! sets @current_path = nil, but defined?(@current_path)
    # still returns true, so Path.current returns nil without querying the DB.
    # Remove the variable entirely so Path.current re-queries and finds our active_path.
    Path.remove_instance_variable(:@current_path) if Path.instance_variable_defined?(:@current_path)
  end

  def stub_fitness_app_steps(steps)
    allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps).and_return(steps)
  end

  describe "#call" do
    context "when user has no prior steps" do
      before { stub_fitness_app_steps(8000) }

      it "records the full step count" do
        expect { service.call }.to change { user.step.reload.total_steps }.by(8000)
      end

      it "sets steps_today to the fitness app total" do
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

      it "sets fitness_app_last_sync_at" do
        expect { service.call }.to change { user.reload.fitness_app_last_sync_at }.from(nil)
      end

      it "returns true" do
        expect(service.call).to be true
      end
    end

    context "when user already entered steps manually today" do
      before do
        user.step.add_steps(3000, force: true)
        path_user.update_progress(active_path)
        stub_fitness_app_steps(8000)
      end

      it "only adds the delta, not the full count" do
        expect { service.call }.to change { user.step.reload.total_steps }.by(5000)
      end

      it "sets steps_today to the fitness app total" do
        service.call
        expect(user.step.reload.steps_today).to eq(8000)
      end

      it "replaces the daily entry with the fitness app total" do
        expect { service.call }.not_to change { DailyStepEntry.count }

        entry = DailyStepEntry.find_by(user: user, path: active_path, date: Date.current)
        expect(entry.steps).to eq(8000)
      end

      it "preserves correct total (previous days + fitness app today)" do
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

    context "when fitness app has fewer steps than manually entered" do
      before do
        user.step.add_steps(10_000, force: true)
        path_user.update_progress(active_path)
        stub_fitness_app_steps(5000)
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
        expect(user.reload.fitness_app_last_sync_at).to be_present
      end
    end

    context "when user is not connected to a fitness app" do
      before { user.update!(fitness_app_uid: nil) }

      it "returns false without calling the API" do
        expect_any_instance_of(FitnessAppClient).not_to receive(:fetch_steps)
        expect(service.call).to be false
      end

      it "logs the reason" do
        expect(Rails.logger).to receive(:warn).with(/no fitness_app_uid/)
        service.call
      end
    end

    context "when there is no active path" do
      before do
        active_path.update!(active: false)
        Path.clear_current_cache!
        stub_fitness_app_steps(8000)
      end

      it "returns false" do
        expect(service.call).to be false
      end

      it "logs the reason" do
        expect(Rails.logger).to receive(:warn).with(/no active path/)
        service.call
      end
    end

    context "when fitness app returns zero steps" do
      before { stub_fitness_app_steps(0) }

      it "does nothing and returns true" do
        expect { service.call }.not_to change { user.step.reload.total_steps }
        expect(service.call).to be true
      end

      it "logs the reason" do
        expect(Rails.logger).to receive(:info).with(/returned 0 steps/)
        service.call
      end
    end

    context "when the fitness app token has expired" do
      before do
        allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps)
          .and_raise(FitnessAppClient::TokenRefreshError, "Token expired")
      end

      it "returns false and does not crash" do
        expect(service.call).to be false
        expect(user.step.reload.total_steps).to eq(0)
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/Token expired/)
        service.call
      end
    end

    context "when the fitness app API returns an error" do
      before do
        allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps)
          .and_raise(FitnessAppClient::ApiError, "API error")
      end

      it "returns false and does not modify steps" do
        expect(service.call).to be false
        expect(user.step.reload.total_steps).to eq(0)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Fitness app sync failed.*ApiError/)
        service.call
      end
    end

    context "when catching up a previous day's steps" do
      let(:yesterday) { Date.current - 1 }

      before do
        DailyStepEntry.create!(user: user, path: active_path, date: yesterday, steps: 6063)
        user.step.update!(total_steps: 6063, steps_today: 6063, last_updated_date: yesterday)
        path_user.update_progress(active_path)
      end

      context "when fitness app has more steps than recorded" do
        before do
          allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps).with(yesterday).and_return(10_509)
        end

        it "adds only the delta" do
          expect { service.call(date: yesterday) }.to change { user.step.reload.total_steps }.by(10_509 - 6063)
        end

        it "updates the daily entry to the correct total" do
          service.call(date: yesterday)

          entry = DailyStepEntry.find_by(user: user, path: active_path, date: yesterday)
          expect(entry.steps).to eq(10_509)
        end
      end

      context "when fitness app returns the same count" do
        before do
          allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps).with(yesterday).and_return(6063)
        end

        it "does not change steps" do
          expect { service.call(date: yesterday) }.not_to change { user.step.reload.total_steps }
        end
      end
    end
  end
end
