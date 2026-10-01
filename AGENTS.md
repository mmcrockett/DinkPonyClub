# AGENTS.md

Dink Pony Club: Rails 8.1 app (Ruby 3.4.10) for running a pickleball league - seasons, teams, rosters, match nights, lineups, scorecards, standings, and player stats. Google OAuth sign-in; deployed with Kamal.

## Commands

- Setup: `bin/setup --skip-server`
- Run: `bin/dev` (Rails server + Tailwind watcher, see `Procfile.dev`)
- Tests: `bin/rails test`; one file: `bin/rails test test/models/game_test.rb`; one test: `bin/rails test test/models/game_test.rb:12`
- System tests (Capybara/Selenium): `bin/rails test:system`
- Lint: `bin/rubocop` (add `-a` to autocorrect)
- Security: `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`
- Everything CI runs locally: `bin/ci` (see `config/ci.rb`)

Run `bin/rubocop` and `bin/rails test` before declaring work done; CI fails on either.

## Layout

- `app/models` - ActiveRecord models (Season, Team, Player, RosterSpot, MatchNight, Match, MatchSlot, Lineup, Game, availability models).
- `app/queries` - read-side objects (standings, player stats, match results). Put computed league numbers here, not in views or controllers.
- `app/services/league` - multi-step operations such as `SnapshotImport`.
- `app/forms` - form objects, e.g. `ScorecardForm`.
- `app/controllers/concerns` - `Authentication` (current player / sign-in) and `SeasonScoped` (season selection). Admin screens live under `app/controllers/admin`.
- Frontend: importmap + Turbo + Stimulus (`app/javascript/controllers`), Tailwind (`app/assets/tailwind`). No Node build step.
- Tests mirror `app/` under `test/` (Minitest + YAML fixtures in `test/fixtures`).

## Conventions

- Follow `.rubocop.yml` (rubocop-rails, -minitest, -performance, -capybara). Notable limits: methods max 20 lines, max 5 assertions per test.
- Single quotes in Ruby, `# frozen_string_literal: true` in app code (not in `db/` or `test/`).
- Comments are rare: add one only for a why the code and tests cannot carry.
- Plain ASCII punctuation in code, comments, docs, and commit messages (`-` not em dashes, straight quotes).
- Only `Player.active` can be signed in (`Authentication` concern); keep new auth paths consistent with that.

## Database

- Dev and test use SQLite (`storage/*.sqlite3`); production uses MySQL. CI passing on SQLite does not prove a migration works in production.
- Write migrations that are safe on MySQL: DDL is not transactional (a failure leaves it half-applied), and MySQL refuses to drop an index a foreign key still needs. The `migrate-mysql` CI job runs migrations against MySQL.
- Never hand-edit `db/schema.rb`; generate it by running migrations.
- Production solid_cache/queue/cable use separate local SQLite files on the Docker volume (see `config/database.yml`).

## Git

- Work on a feature branch; do not commit directly to `main`.
- Commit messages: one terse line stating intent.
- PRs are squash-merged; title format is `PR <n> - <what changed>`.
- Never commit secrets, `config/*.key`, `.env*`, `storage/`, `log/`, `tmp/`, or the spreadsheets at the repo root.
