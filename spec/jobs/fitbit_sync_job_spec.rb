require 'rails_helper'

RSpec.describe FitbitSyncJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers
  include_context "user with path progress"

  before do
    user.update!(fitbit_uid: "TESTUID", fitbit_access_token: "token123", timezone: "America/New_York")
  end

  describe "#perform" do
    it "calls FitbitSyncService for the user" do
      sync_service = instance_double(FitbitSyncService, call: true)
      allow(FitbitSyncService).to receive(:new).with(user).and_return(sync_service)

      described_class.new.perform(user.id)

      expect(sync_service).to have_received(:call)
    end

    it "skips users who have disconnected Fitbit" do
      user.update!(fitbit_uid: nil)

      expect(FitbitSyncService).not_to receive(:new)

      described_class.new.perform(user.id)
    end

    it "does nothing for non-existent user IDs" do
      expect(FitbitSyncService).not_to receive(:new)
      described_class.new.perform(-1)
    end

    it "reschedules itself after running" do
      allow(FitbitSyncService).to receive_message_chain(:new, :call).and_return(true)

      expect {
        described_class.new.perform(user.id)
      }.to have_enqueued_job(described_class).with(user.id)
    end

    it "does not reschedule if user disconnected Fitbit" do
      user.update!(fitbit_uid: nil)

      expect {
        described_class.new.perform(user.id)
      }.not_to have_enqueued_job(described_class)
    end

    it "still reschedules when tokens are expired but uid exists" do
      user.update!(fitbit_access_token: nil, fitbit_refresh_token: nil, fitbit_token_expires_at: nil)
      allow_any_instance_of(FitbitSyncService).to receive(:call).and_return(false)

      expect {
        described_class.new.perform(user.id)
      }.to have_enqueued_job(described_class).with(user.id)
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
      travel_to Time.find_zone("America/New_York").parse("2026-02-16 23:55:00") do
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
end
