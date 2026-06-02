namespace :encryption do
  # Pre-deploy safety check. Run against a prod snapshot (or `heroku run`)
  # BEFORE backfilling. Exits non-zero if email case-collisions would break the
  # backfill, so it can gate a deploy script.
  desc "Pre-deploy check: counts + email case-collisions before backfill"
  task preflight: :environment do
    report = EncryptionPreflight.report
    puts "Users: #{report[:users]}"
    puts "Steps: #{report[:steps]}"

    collisions = report[:email_case_collisions]
    if collisions.empty?
      puts "Email case-collisions: none — safe to backfill."
    else
      puts "Email case-collisions found (#{collisions.size}) — RESOLVE BEFORE BACKFILL:"
      collisions.each { |ids| puts "  user ids #{ids.join(', ')} share an email once downcased" }
      abort "Preflight failed: resolve duplicate emails before encrypting."
    end
  end

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
