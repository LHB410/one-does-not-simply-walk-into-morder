# Changelog

All notable changes to the Walk to Mordor project.

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
