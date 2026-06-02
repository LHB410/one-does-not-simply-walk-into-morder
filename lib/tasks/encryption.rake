namespace :encryption do
  # One-off backfill to convert existing plaintext user PII (email + health
  # OAuth tokens) into encrypted form at rest. Active Record Encryption does NOT
  # rewrite existing rows automatically; this forces each row through encryption.
  #
  # Runbook (so no existing user is locked out):
  #   1. Deploy with AR_ENCRYPTION_SUPPORT_UNENCRYPTED=true and
  #      AR_ENCRYPTION_EXTEND_QUERIES=true (app reads plaintext + ciphertext).
  #   2. Confirm an existing user can still log in.
  #   3. Run: bin/rails encryption:backfill_users
  #   4. Confirm the same user can still log in and tokens read back.
  #   5. Set both flags back to false.
  desc "Re-encrypt existing plaintext user PII (email, health tokens)"
  task backfill_users: :environment do
    total = User.count
    done = 0

    User.find_each do |user|
      user.encrypt
      done += 1
      puts "Re-encrypted #{done}/#{total} users" if (done % 100).zero?
    end

    puts "Done. Re-encrypted #{done}/#{total} users."
  end
end
