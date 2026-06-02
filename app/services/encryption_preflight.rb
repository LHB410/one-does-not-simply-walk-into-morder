# Pre-deploy safety check for the PII encryption rollout. Run BEFORE the
# encryption:backfill_users task (locally against a prod snapshot, or via
# `heroku run rails encryption:preflight`).
#
# The key check is email case-collisions: `encrypts :email, downcase: true`
# normalizes case, so two legacy rows whose emails differ only by case would
# violate the unique index when the backfill downcases + encrypts them.
class EncryptionPreflight
  def self.report
    {
      users: User.count,
      steps: Step.count,
      email_case_collisions: email_case_collisions
    }
  end

  # Reads the raw email column (pre-backfill values are plaintext) and returns
  # arrays of user ids that share an email once downcased. Empty == safe.
  def self.email_case_collisions
    rows = User.connection.select_rows("SELECT id, email FROM users")

    rows.group_by { |(_id, email)| email.to_s.downcase }
        .values
        .select { |group| group.size > 1 }
        .map { |group| group.map { |(id, _email)| id.to_i } }
  end
end
