# Changelog

All notable changes to the Walk to Mordor project.

## [1.2.1] - Remove Golden Ring Around User Token

### Removed
- The golden ring that was drawn around the current user's map token when parked on a milestone with a shop URL. The milestone pin is no longer clickable, so the ring served no purpose and lingered (preserved by `data-turbo-permanent`) even after the pin was collected.

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
