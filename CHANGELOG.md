# Changelog

All notable changes to the Walk to Mordor project.

## [3.2.0] - Account Closure, Privacy Policy & Terms

### Added
- **Account tab** in the stats popup: change your display name, and a collapsible **Danger zone** holding the account-closure action (kept collapsed and away from the logout button so it can't be clicked by accident).
- **Close My Account**: a permanent account-deletion flow (`AccountClosure` service + `AccountsController#destroy`). Closing an account revokes the user's Google Health grant, deletes the user and all associated data (steps, daily entries, path progress, milestone pins), and logs them out. If a group leader closes their account, leadership transfers to the next-joined member; if they were the group's last member, the now-empty group is deleted.
- **Privacy Policy** (`/privacy`) and **Terms of Service** (`/terms`) pages, linked from the logged-out landing screen. The Privacy Policy includes the Google API Services "Limited Use" disclosure required for OAuth restricted-scope verification, and documents the account-closure deletion path.
- **App logo** now used as the browser-tab favicon (`walk-to-mordor-logo.png`), replacing the default Rails icon.

### Changed
- **Google Health disconnect now revokes the token with Google** (`HealthClient.revoke_token`), not just locally — disconnecting invalidates the grant on Google's side, not only in our database. Revocation is best-effort, so a failed revoke never blocks the disconnect.

## [3.1.1] - Fix mobile milestone placement

### Fixed
- **Milestones/path pushed up on mobile**: the map is now locked to a fixed 4:3 box (matching the `map_of_middle_earth.svg` aspect ratio) and centered within its pane at every viewport. Previously the 4:3 background image (`object-contain`) and the 1:1 overlay SVG (`viewBox="0 0 100 100"`, `xMidYMid meet`) only aligned at desktop-width aspect ratios; on narrower/taller mobile panes the image letterboxed downward while the square overlay stayed top-anchored, shifting the path and milestone markers up off the terrain. Existing milestone coordinates are unchanged.

### Security
- **Puma updated 6.6.0 → 8.0.2**, clearing two High-severity advisories in the PROXY Protocol v1 parser (CVE-2026-47736 remote memory exhaustion, CVE-2026-47737 repeated protocol headers on persistent connections). The vulnerable path was not enabled in this app, but the bump keeps the `bundle-audit` CI gate green.

## [3.1.0] - Security Hardening

### Added
- **Login rate limiting** via `rack-attack` (`config/initializers/rack_attack.rb`): a tight per-IP login throttle (10/min) to blunt brute-force and credential-stuffing against the shared group password, plus a global per-IP request flood limit (300/5min). Throttled requests get a `429` with a `Retry-After` header.

### Security
- **Session fixation fixed**: `SessionsController` now calls `reset_session` before establishing the logged-in session, and fully tears down the session on logout (previously only the user id was cleared).
- **Password length policy**: admin/legacy users now require a minimum 8-character password (`minimum: 8`, `allow_nil: true`), mirroring the group password policy.
- **Production data exposure closed**: `*.dump` and `*.sql` are now gitignored so database dumps can't be committed.

## [3.0.0] - Groups, Public Sign-up & PII Encryption

### Added
- **Groups**: a `Group` has many users; a user belongs to one group. Each group has a single shared password (`has_secure_password`) that members log in with, and a leader (`Group#leader`, never an admin) who is the only one able to change it (`GroupsController#update_password`).
- **Public sign-up**: a logged-out entry screen offers "Log in" or "Sign up"; the sign-up page lets a group leader register their group, themselves, and their members in one step. The transactional creation logic lives in `GroupRegistration` (`app/services/`); the controller is thin.
- **PII encryption at rest**: `users.email` (deterministic + downcased, so login lookups and uniqueness still work) and the health OAuth tokens are encrypted via Active Record Encryption. Keys are read from the environment (Heroku config vars in production).
- Ops tooling: `encryption:preflight` (pre-deploy safety check for email case-collisions) and `encryption:backfill_users` (one-off plaintext→encrypted migration) rake tasks, plus `DEPLOY.md` with the full deploy + rollback runbook.

### Changed
- Authentication branches by membership: group members authenticate against their group's shared password, admins/legacy users against their own.
- The dashboard is scoped to the current user's group, so groups never see each other's members.
- New members are placed at the start of the active path on sign-up via `PathUser.start_for` (shared with the seeds) so they appear on the map immediately.
- `users.password_digest` is now nullable (group members have no individual password) and `users.email` widened to `text` (encrypted ciphertext exceeds varchar(255)).
- Removed the unused `sidekiq` gem — background work runs on Solid Queue. Updated `erb` to 6.0.4 (security advisory).

### Fixed
- Members' step cards no longer show a misleading "already updated" message (or an edit form) to non-admin viewers. The step form now renders only for the user themselves or an admin; "Steps already updated today" appears only on your own card when you have actually updated today.

## [2.0.0] - Replace Fitbit with Google Health API

### Changed
- Step sync now uses the **Google Health API** instead of the Fitbit Web API. The integration is provider-neutral: `HealthClient`, `HealthSyncService`, `HealthSyncJob`, and `HealthController` replace their `Fitbit*` counterparts, and the `users.fitbit_*` columns were renamed to `health_*`.
- OAuth now uses Google's official `Signet::OAuth2::Client` (via the `googleauth` gem) for the token lifecycle; the `oauth2` gem was dropped. Step data is read over Faraday from the `dailyRollUp` endpoint.

### Added
- Shared `Loggable` mixin (`app/lib/loggable.rb`) providing a terse `log(level, message)` wrapper over `Rails.logger`. Included across services, controllers, and models so all logging goes through one helper.

### Removed
- All Fitbit code, routes (`/auth/fitbit*` → `/auth/health*`), the Fitbit Stimulus controller, and the `FITBIT_*` environment variables (now `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`).

### Migration notes
- Google does not accept transferred Fitbit tokens, so stored token values are cleared on migrate. Each user must reconnect once via **Connect Google Health**. Step history (`steps`, `daily_step_entries`, `path_users`) is preserved untouched.

## [1.2.1] - Remove Golden Ring Around User Token

### Removed
- The golden ring that was drawn around the current user's map token when parked on a milestone with a shop URL. The milestone pin is no longer clickable, so the ring served no purpose and lingered (preserved by `data-turbo-permanent`) even after the pin was collected.

### Changed
- Bumped dependencies to resolve CVEs flagged by bundle-audit: `faraday` 2.14.1 → 2.14.2 (GHSA-5rv5-xj5j-3484), `jwt` 3.1.2 → 3.2.0 (CVE-2026-45363, High).

## [1.2.0] - Cache User Stats with Solid Cache

### Added
- Solid Cache wired up as the `Rails.cache` backend in development and production. Uses the primary Postgres database, so no Redis dyno or extra Heroku addon is required.
- `StatsHelper#pace_estimates` and `#personal_bests` now cache their results per user, keyed off `Step#cache_key_with_version`. The cache invalidates automatically whenever steps are added (via `Step#add_steps`), so the stats popup loads quickly without staleness.

### Changed
- `Procfile` now runs `rails db:migrate` in the Heroku release phase, so future migrations apply automatically before new dynos take traffic. Failed migrations roll back the deploy.
- Bumped transitive dependencies to resolve CVEs flagged by bundle-audit: `addressable` 2.8.7 → 2.9.0, `net-imap` 0.5.9 → 0.6.4, `nokogiri` 1.19.2 → 1.19.3.

## [1.1.1] - Fix Pace Calculator Average

### Fixed
- Pace calculator now averages steps over total calendar days (including gaps) instead of only days with entries, giving a more realistic pace estimate when users bulk-log steps after missing days

## [1.1.0] - Moria Milestone Badge & Link

### Added
- Moria milestone badge icon (`moria.svg`)
- Specific Etsy listing link for Moria enamel pin

## [1.0.0] - Stats Popup & CI Fixes

### Added
- **Stats popup** — "View Stats" button replaces "Daily Step Report" with a tabbed popup containing Daily Steps, Pace Calculator, Personal Bests, and Badges Collected
- **Badges Collected tab** — collected milestone pin badges now display in the stats popup with larger icons instead of on the dashboard
- **Pace Calculator** — estimates arrival dates for upcoming milestones based on average daily steps
- **Personal Bests** — shows top 5 step days with gold/silver/bronze styling
- **bundler-audit** — added gem vulnerability scanning to CI
- Turbo now loads correctly via importmap (fixed broken Stimulus controllers)
- CI now builds Tailwind CSS before running tests

### Changed
- Moved badge display from dashboard sidebar into the stats popup "Badges" tab
- CI simplified to: vulnerability audit, rubocop, and rspec
- Updated Rails from 8.0.2 to 8.0.5 (security patches)
- Updated nokogiri and rack to resolve CVEs

### Fixed
- Removed duplicate `turbo_include_tags` in layout that broke importmap
- Fixed CI test failures caused by missing Tailwind CSS asset
- Fixed FitbitClient specs failing in CI due to missing env vars

## [0.6.0] - Fitbit Catchup Job
- Added 6 AM catchup sync job to capture same-day Fitbit step updates

## [0.5.0] - Milestone Pin Links
- Added shop URLs and pin icons to milestones
- Pin purchase tracking and badge display on user cards
- Layout fixes

## [0.4.0] - Fitbit Integration
- OAuth2 Fitbit sync via FitbitClient and FitbitSyncService
- Automatic daily sync job at 11:59 PM in user's timezone
- Token auto-refresh on expiry
- Connect/disconnect/reconnect UI

## [0.3.0] - Daily Step Report
- Paginated daily step history popup via Turbo Frame
- Frontend polish and mobile improvements

## [0.2.0] - Database & Performance Improvements
- Fixed N+1 queries with eager loading
- DailyStepEntry audit log
- Milestone step progression bug fix
- Removed Google Sheets integration and clockwork

## [0.1.0] - Initial Release
- Rails 8 app with Hotwire (Turbo + Stimulus) and Tailwind CSS
- Interactive Middle Earth SVG map with panzoom
- User tokens positioned along the journey path
- Step tracking with once-per-day rule and admin override
- 12 milestones from Shire to Grey Havens (3,659 miles)
- Fellowship progress sidebar with per-user stats
- Login/logout with bcrypt authentication
- Mobile responsive layout
