require 'rails_helper'

RSpec.describe FitnessAppSyncJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers
  include_context "user with path progress"

  before do
    user.update!(fitness_app_provider: "fitbit", fitness_app_uid: "TESTUID", fitness_app_access_token: "token123", timezone: "America/New_York")
  end

  describe "#perform" do
    context "with a connected user" do
      before do
        Path.remove_instance_variable(:@current_path) if Path.instance_variable_defined?(:@current_path)
        allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps).and_return(5000)
      end

      it "syncs steps via FitnessAppSyncService" do
        described_class.new.perform(user.id)

        expect(user.reload.fitness_app_last_sync_at).to be_present
        expect(user.step.reload.total_steps).to eq(5000)
      end

      it "passes the date to FitnessAppSyncService when provided" do
        yesterday = (Date.current - 1).to_s

        described_class.new.perform(user.id, yesterday)

        expect(user.reload.fitness_app_last_sync_at).to be_present
      end
    end

    context "when user has disconnected their fitness app" do
      before { user.update!(fitness_app_uid: nil) }

      it "does not sync" do
        described_class.new.perform(user.id)

        expect(user.reload.fitness_app_last_sync_at).to be_nil
      end
    end

    it "does nothing for non-existent user IDs" do
      expect { described_class.new.perform(-1) }.not_to raise_error
    end

    context "nightly run scheduling" do
      before do
        Path.remove_instance_variable(:@current_path) if Path.instance_variable_defined?(:@current_path)
        allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps).and_return(5000)
      end

      it "reschedules nightly sync and catchup after a nightly run" do
        expect {
          described_class.new.perform(user.id)
        }.to have_enqueued_job(described_class).with(user.id).and have_enqueued_job(described_class).with(user.id, Date.current.to_s)
      end

      it "does not reschedule after a catchup run" do
        expect {
          described_class.new.perform(user.id, Date.current.to_s)
        }.not_to have_enqueued_job(described_class)
      end
    end

    context "when user disconnected fitness app" do
      before { user.update!(fitness_app_uid: nil) }

      it "does not reschedule" do
        expect {
          described_class.new.perform(user.id)
        }.not_to have_enqueued_job(described_class)
      end
    end

    context "when tokens are expired but uid exists" do
      before do
        user.update!(fitness_app_access_token: nil, fitness_app_refresh_token: nil, fitness_app_token_expires_at: nil)
        allow_any_instance_of(FitnessAppClient).to receive(:fetch_steps)
          .and_raise(FitnessAppClient::TokenRefreshError, "Token expired")
      end

      it "still reschedules" do
        expect {
          described_class.new.perform(user.id)
        }.to have_enqueued_job(described_class).with(user.id)
      end
    end
  end

  describe ".schedule_for" do
    it "enqueues a job for the user" do
      expect {
        described_class.schedule_for(user)
      }.to have_enqueued_job(described_class).with(user.id)
    end
  end

  describe ".next_sync_time" do
    it "returns 23:59 in the user's timezone" do
      result = described_class.next_sync_time(user)
      in_user_zone = result.in_time_zone("America/New_York")

      expect(in_user_zone.hour).to eq(23)
      expect(in_user_zone.min).to eq(59)
    end

    it "returns tomorrow if 23:59 has already passed today" do
      travel_to Time.find_zone("America/New_York").parse("2026-02-16 23:59:30") do
        result = described_class.next_sync_time(user)
        in_user_zone = result.in_time_zone("America/New_York")

        expect(in_user_zone.to_date).to eq(Date.parse("2026-02-17"))
      end
    end

    it "falls back to app timezone when user has no timezone set" do
      user.update!(timezone: nil)

      expect { described_class.next_sync_time(user) }.not_to raise_error
    end
  end

  describe ".next_catchup_time" do
    it "returns 6:00 AM in the user's timezone" do
      result = described_class.next_catchup_time(user)
      in_user_zone = result.in_time_zone("America/New_York")

      expect(in_user_zone.hour).to eq(6)
      expect(in_user_zone.min).to eq(0)
    end

    it "returns tomorrow morning if 6:00 AM has already passed today" do
      travel_to Time.find_zone("America/New_York").parse("2026-02-16 10:00:00") do
        result = described_class.next_catchup_time(user)
        in_user_zone = result.in_time_zone("America/New_York")

        expect(in_user_zone.to_date).to eq(Date.parse("2026-02-17"))
      end
    end
  end
end
