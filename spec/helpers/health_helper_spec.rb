require "rails_helper"

RSpec.describe HealthHelper, type: :helper do
  describe "#health_reminder_due?" do
    let(:user) { create(:user) }

    # Travel to a known day on (and off) the cycle rather than a real date.
    let(:renewal_day) { HealthHelper::REMINDER_EPOCH + (HealthHelper::REMINDER_INTERVAL_DAYS * 4) }
    let(:ordinary_day) { renewal_day + 1 }

    before { user.update!(health_uid: "ABC123", health_access_token: "token") }

    it "prompts every connected user on a renewal day" do
      travel_to(renewal_day) do
        expect(helper.health_reminder_due?(user)).to be true
      end
    end

    it "recurs on the next renewal day" do
      travel_to(renewal_day + HealthHelper::REMINDER_INTERVAL_DAYS) do
        expect(helper.health_reminder_due?(user)).to be true
      end
    end

    it "stays hidden between renewal days" do
      travel_to(ordinary_day) do
        expect(helper.health_reminder_due?(user)).to be false
      end
    end

    it "prompts off-cycle when the grant has already lapsed" do
      user.update!(health_access_token: nil)

      travel_to(ordinary_day) do
        expect(helper.health_reminder_due?(user)).to be true
      end
    end

    it "ignores a user who has never connected" do
      user.update!(health_uid: nil, health_access_token: nil)

      travel_to(renewal_day) do
        expect(helper.health_reminder_due?(user)).to be false
      end
    end

    it "ignores a logged-out visitor" do
      travel_to(renewal_day) do
        expect(helper.health_reminder_due?(nil)).to be false
      end
    end
  end
end
