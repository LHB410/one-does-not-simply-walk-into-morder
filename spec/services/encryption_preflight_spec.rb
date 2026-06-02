require 'rails_helper'

RSpec.describe EncryptionPreflight do
  # Insert rows directly so we can simulate legacy mixed-case plaintext emails.
  # The model would downcase + reject these on write, so the model can't create them.
  def insert_raw_user(email)
    User.connection.select_value(
      "INSERT INTO users (name, email, token_color, created_at, updated_at) " \
      "VALUES ('U', #{User.connection.quote(email)}, '#4169E1', NOW(), NOW()) RETURNING id"
    ).to_i
  end

  describe ".email_case_collisions" do
    it "groups users whose emails collide only after downcasing" do
      id1 = insert_raw_user("Frodo@Shire.me")
      id2 = insert_raw_user("frodo@shire.me")
      insert_raw_user("sam@shire.me") # distinct, must not be reported

      collisions = described_class.email_case_collisions

      expect(collisions.size).to eq(1)
      expect(collisions.first).to contain_exactly(id1, id2)
    end

    it "is empty when every email is already unique case-insensitively" do
      insert_raw_user("frodo@shire.me")
      insert_raw_user("sam@shire.me")

      expect(described_class.email_case_collisions).to be_empty
    end
  end

  describe ".report" do
    it "reports user and step counts plus collisions" do
      insert_raw_user("frodo@shire.me")

      report = described_class.report

      expect(report[:users]).to eq(User.count)
      expect(report[:steps]).to eq(Step.count)
      expect(report[:email_case_collisions]).to eq([])
    end
  end
end
