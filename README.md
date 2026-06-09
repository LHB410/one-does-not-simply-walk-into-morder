# One Does Not Simply Walk Into Mordor

A collaborative, Lord of the Rings–themed fitness tracker. A group of friends turn their daily steps into shared progress along the 3,659-mile journey from the Shire to the Grey Havens — staying motivated together, even when they're far apart.

<a href="https://buymeacoffee.com/laurabrookx" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="42"></a>

## What it does

- **Walk together** — your group shares one path and one map, and everyone sees each other's position.
- **Steps → miles** — daily steps convert to miles (2,112 steps per mile) and move you along the journey.
- **Milestones** — celebrate reaching iconic places like Rivendell, Moria, and Mount Doom, and collect a commemorative pin (purchased from third-party vendors at your discretion).
- **Stats** — daily history, pace estimates to the next milestone, personal bests, and badges.
- **Optional auto-sync** — connect Google Health to sync steps automatically, or just log them by hand.

## How it works

Each group shares a single password and its own map, so groups never see each other's members. New members start at the Shire and appear on the map right away. Steps are recorded once per day, converted to miles, and used to recalculate each person's current milestone and progress.

## Getting started

You'll need **Ruby 3.4.4** and **PostgreSQL**.

```bash
bundle install
rails db:create db:migrate db:seed
rails server
```

The app runs at http://localhost:3000. Seeding sets up the full Shire → Grey Havens path, its milestones, and a few sample users.

### Optional: Google Health sync

Add `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (plus the `AR_ENCRYPTION_*` keys used to encrypt personal data) to a `.env` file. When a user connects Google Health, a daily job syncs their steps at 11:59 PM in their timezone. Without it, steps are entered manually.

## Tech stack

Rails 8 · Ruby 3.4.4 · PostgreSQL · Hotwire (Turbo + Stimulus) · Tailwind CSS · Solid Queue · Active Record Encryption for personal data.

## Testing

```bash
bundle exec rspec
```

RSpec + FactoryBot + Shoulda Matchers + Capybara.

## Contributing

Contributions are welcome! Fork the repo, create a branch, make sure `bundle exec rspec` passes, and open a pull request — bug fixes, features, docs, and test coverage are all appreciated. Feel free to adapt the project for your own fellowship.

## Support

If you enjoy the app, you can support its development:

<a href="https://buymeacoffee.com/laurabrookx" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="42"></a>

## License

Private project — all rights reserved.
