require 'rails_helper'

RSpec.describe HealthSyncJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers
  include_context "user with path progress"

  before do
    user.update!(health_uid: "TESTUID", health_access_token: "token123", timezone: "America/New_York")
  end

  describe "#perform" do
    it "calls HealthSyncService for the user with their local date" do
      sync_service = instance_double(HealthSyncService, call: true)
      allow(HealthSyncService).to receive(:new).with(user).and_return(sync_service)

      described_class.new.perform(user.id)

      expect(sync_service).to have_received(:call).with(date: Time.current.in_time_zone(user.timezone).to_date)
    end

    it "syncs the user's LOCAL date, not the server's UTC date" do
      # 03:30 UTC on Jun 10 is still 23:30 on Jun 9 in America/New_York. The
      # nightly run must sync Jun 9 (the day ending locally), not Jun 10 (UTC).
      sync_service = instance_double(HealthSyncService, call: true)
      allow(HealthSyncService).to receive(:new).with(user).and_return(sync_service)

      travel_to Time.utc(2026, 6, 10, 3, 30) do
        described_class.new.perform(user.id)
      end

      expect(sync_service).to have_received(:call).with(date: Date.new(2026, 6, 9))
    end

    it "passes the date to HealthSyncService when provided" do
      yesterday = (Date.current - 1).to_s
      sync_service = instance_double(HealthSyncService, call: true)
      allow(HealthSyncService).to receive(:new).with(user).and_return(sync_service)

      described_class.new.perform(user.id, yesterday)

      expect(sync_service).to have_received(:call).with(date: Date.parse(yesterday))
    end

    it "skips users who have disconnected" do
      user.update!(health_uid: nil)

      expect(HealthSyncService).not_to receive(:new)

      described_class.new.perform(user.id)
    end

    it "does nothing for non-existent user IDs" do
      expect(HealthSyncService).not_to receive(:new)
      described_class.new.perform(-1)
    end

    it "reschedules nightly sync and catchup after a nightly run" do
      allow(HealthSyncService).to receive_message_chain(:new, :call).and_return(true)
      local_today = Time.current.in_time_zone(user.timezone).to_date.to_s

      expect {
        described_class.new.perform(user.id)
      }.to have_enqueued_job(described_class).with(user.id, nil, nil).and have_enqueued_job(described_class).with(user.id, local_today, nil)
    end

    it "schedules the catch-up for the user's LOCAL date, not the UTC date" do
      allow(HealthSyncService).to receive_message_chain(:new, :call).and_return(true)

      travel_to Time.utc(2026, 6, 10, 3, 30) do
        expect {
          described_class.new.perform(user.id)
        }.to have_enqueued_job(described_class).with(user.id, "2026-06-09", nil)
      end
    end

    it "does not reschedule after a catchup run" do
      allow(HealthSyncService).to receive_message_chain(:new, :call).and_return(true)

      expect {
        described_class.new.perform(user.id, Date.current.to_s)
      }.not_to have_enqueued_job(described_class)
    end

    it "does not reschedule if user disconnected" do
      user.update!(health_uid: nil)

      expect {
        described_class.new.perform(user.id)
      }.not_to have_enqueued_job(described_class)
    end

    it "still reschedules when tokens are expired but uid exists" do
      user.update!(health_access_token: nil, health_refresh_token: nil, health_token_expires_at: nil)
      allow_any_instance_of(HealthSyncService).to receive(:call).and_return(false)

      expect {
        described_class.new.perform(user.id)
      }.to have_enqueued_job(described_class).with(user.id, nil, nil)
    end
  end

  describe ".schedule_for" do
    it "mints a fresh sync token on the user and enqueues a job carrying it" do
      expect {
        described_class.schedule_for(user)
      }.to change { user.reload.health_sync_token }.from(nil)

      expect(described_class).to have_been_enqueued.with(user.id, nil, user.reload.health_sync_token)
    end

    it "supersedes a previous schedule: reconnecting changes the token" do
      described_class.schedule_for(user)
      first_token = user.reload.health_sync_token

      described_class.schedule_for(user)

      expect(user.reload.health_sync_token).not_to eq(first_token)
    end
  end

  describe "superseded (stale) chains" do
    before { user.update!(health_sync_token: "current-token") }

    it "does not sync when the job's token no longer matches the user's" do
      expect(HealthSyncService).not_to receive(:new)

      described_class.new.perform(user.id, nil, "stale-token")
    end

    it "does not reschedule a stale chain (so old duplicate chains die off)" do
      expect {
        described_class.new.perform(user.id, nil, "stale-token")
      }.not_to have_enqueued_job(described_class)
    end

    it "syncs and reschedules when the token matches" do
      allow(HealthSyncService).to receive_message_chain(:new, :call).and_return(true)

      expect {
        described_class.new.perform(user.id, nil, "current-token")
      }.to have_enqueued_job(described_class).with(user.id, nil, "current-token")
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
