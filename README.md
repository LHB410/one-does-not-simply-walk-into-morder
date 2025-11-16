# One Does Not Simply Walk Into Mordor

A collaborative fitness tracking application that allows a group of friends to walk "to Mordor" together, even when they're far apart. This Lord of the Rings-themed app helps remote friends stay motivated and accountable to each other as they exercise together on their journey through Middle-earth.

## Overview

This app transforms your daily steps into progress along the epic journey from the Shire to Mordor and back. Friends can join together on the same path, track their progress on an interactive map of Middle-earth, and celebrate reaching milestones by purchasing physical pins as keepsakes of their shared adventure (pins purchsed from 3rd party vendors at users perogative).

### Key Features

- **Shared Journey**: Multiple users can walk the same path together, keeping each other accountable
- **Interactive Map**: Visual representation of Middle-earth showing each friend's current location
- **Milestone Tracking**: Celebrate reaching iconic locations like Rivendell, Moria, Mount Doom, and more
- **Physical Pins**: At each milestone, users can purchase a physical pin as a reminder of their progress
- **Daily Step Logging**: Track your steps each day and see your progress toward the next milestone
- **Progress Visualization**: See how far you and your friends have come on your journey

## Table of Contents

- [Technology Stack](#technology-stack)
- [System Dependencies](#system-dependencies)
- [Configuration](#configuration)
- [Database Setup](#database-setup)
- [Running the Application](#running-the-application)
- [How It Works](#how-it-works)
- [Testing](#testing)
- [Services](#services)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## Technology Stack

- **Ruby**: 3.4.4
- **Rails**: 8.0.2
- **Database**: PostgreSQL
- **Frontend**:
  - Tailwind CSS for styling
  - Stimulus.js for JavaScript interactions
  - Turbo for SPA-like navigation
- **Scheduled Tasks**: Clockwork for running scheduled jobs
- **Authentication**: bcrypt for secure password hashing
- **External Services**: Google Sheets API integration

## System Dependencies

- Ruby 3.4.4
- PostgreSQL

## Configuration

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```
3. Set up environment variables (create a `.env` file):
   - Database credentials
   - Google Sheets API credentials (optional - only needed if you want to use Google Sheets for step updates)
   - Any other required API keys

## Database Setup

1. Create and migrate the database:
   ```bash
   rails db:create
   rails db:migrate
   ```

2. Seed the database with initial data (paths, milestones, and sample users):
   ```bash
   rails db:seed
   ```

The seed file creates:
- A complete journey path from Shire to Grey Havens (3,659 miles total)
- 12 milestones including Shire, Rivendell, Moria, Mount Doom, Minas Tirith, and more
- Sample users (you can modify these in `db/seeds.rb`)

## Running the Application

### Development

Start the Rails server:
```bash
rails server
```

The application will be available at `http://localhost:3000`

### Scheduled Tasks

If Google Sheets integration is configured, the app uses Clockwork to schedule daily step updates. The scheduled job runs at 11:59 PM CST daily to fetch step data from a Google Sheet (which users must manually update) and update each user's progress. Clockwork is configured in `lib/clockwork.rb`. Note: The app works without Google Sheets - users can update their steps directly in the app instead.

## How It Works

### The Journey

The app tracks a single continuous journey from the Shire to Mordor and back to the Grey Havens, covering 3,659 miles total. The journey is divided into milestones representing key locations from The Lord of the Rings:

1. **Shire** (Starting point)
2. **Rivendell** (458 miles)
3. **Moria** (633 miles)
4. **Lothlórien** (755 miles)
5. **Falls of Rauros** (1,144 miles)
6. **Dead Marshes** (1,246 miles)
7. **Shelob's Lair** (1,435 miles)
8. **Mount Doom** (1,614 miles)
9. **Minas Tirith** (1,774 miles)
10. **Isengard** (2,309 miles)
11. **Hobbiton** (3,399 miles)
12. **Grey Havens** (3,659 miles - Final destination)

### Step Conversion

Steps are converted to miles using the average of 2,112 steps per mile. Steps can be updated in two ways:
- **Manual Entry**: Users can update their daily steps directly in the app at any time
- **Google Sheets** (optional): Users manually update a Google Sheet with their step counts, and the daily job fetches this data at 11:59 PM CST each night

All steps are automatically converted to progress along the path.

### User Features

- **Step Updates**: Update your daily steps directly in the app, or manually update a Google Sheet (if configured) for automatic nightly processing
- **Progress Tracking**: See how many miles you've walked and how far until the next milestone
- **Group Visibility**: View all friends' progress on the interactive map
- **Milestone Achievements**: When you reach a milestone, you can purchase a physical pin to commemorate the achievement

## Testing

Run the test suite:

```bash
bundle exec rspec
```

The app uses RSpec for testing with FactoryBot for test data and Shoulda Matchers for model validations.

## Services

- **Daily Step Update Job**: If Google Sheets is configured, automatically fetches step data from a Google Sheet (which users must manually update) and updates user progress (runs via Clockwork at 11:59 PM CST daily)
- **Google Sheets Service**: Optional integration that retrieves daily step counts from a Google Sheet. Users must manually update the Google Sheet with their step counts - the service only reads from it, it does not write to it.

## Project Structure

- `app/models/`: Core models (User, Path, Step, Milestone, PathUser)
- `app/controllers/`: Dashboard, Sessions, and Steps controllers
- `app/views/`: ERB templates with Tailwind CSS styling
- `app/services/`: Business logic services
- `app/jobs/`: Background job definitions
- `db/seeds.rb`: Initial data setup including paths and milestones

## Contributing

This is a personal project for friends to track their fitness journey together. We welcome contributions from anyone who wants to help improve the app!

### How to Contribute

1. **Fork the repository** and clone it to your local machine
2. **Create a new branch** for your feature or bug fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** and ensure tests pass:
   ```bash
   bundle exec rspec
   ```
4. **Commit your changes** with clear, descriptive commit messages
5. **Push to your fork** and open a Pull Request

### What We're Looking For

- Bug fixes and improvements
- New features that enhance the user experience
- Documentation improvements
- Performance optimizations
- Test coverage improvements

Feel free to fork and adapt this project for your own group, or submit PRs to help make it better for everyone!

## License

Private project - All rights reserved
