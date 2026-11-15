# AGENTS.md

Dink Pony Club: Rails 8.1 app (Ruby 3.4.12) for running a pickleball league - seasons, teams, rosters, match nights, lineups, scorecards, standings, and player stats. Google OAuth sign-in; deployed with Kamal.

## Commands

Docker is preferred for development, tests, and linting. Install Docker and start its daemon first. Each command builds or reuses the development image and runs a separate container; tests and lint do not require the server to be running.

- Run: `bin/dev-docker`, then open http://localhost:3312. Stop with Ctrl-C.
- Tests: `bin/test-docker`; one file: `bin/test-docker test/models/game_test.rb`; one test: `bin/test-docker test/models/game_test.rb:12`
- Lint: `bin/rubocop-docker` (add `-a` to autocorrect)
- System tests (Capybara/Selenium): `bin/system-test-docker`; one file: `bin/system-test-docker test/system/photo_gallery_test.rb`. The development image includes Chromium and its driver.
- Native fallback: `bin/setup --skip-server`, `bin/dev`, `bin/rails test`, `bin/rails test:system`, and `bin/rubocop`. Native system tests require Chrome and libvips on the host.
- Security: `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`
- Everything CI runs locally: `bin/ci` (see `config/ci.rb`)

Docker mounts the current checkout, including its `storage/` databases and optional `config/master.key`; Google sign-in requires valid local credentials. Starting the app runs `db:prepare`, which may load seeds for a new database. Concurrent test runs in the same checkout share the test database and can interfere.

Run `bin/rubocop-docker` and `bin/test-docker` before declaring work done; CI fails on either.

## Layout

- `app/models` - ActiveRecord models (Season, Team, Player, RosterSpot, MatchNight, Match, MatchSlot, Lineup, Game, availability models, `Fee` and `Charge`).
  - Money is stored as integer cents; parse user-entered dollars with `Dollars.to_cents`. A `Fee` is a season's catalog entry (`applies_to_all` charges every rostered player, otherwise opt-in); a `Charge` is one player's amount owed and `paid_cents` for a fee.
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

- Dev, test, and production primary use SQLite (`storage/*.sqlite3`; production's lives on the Docker volume). The shared MySQL host is an hourly backup copy (`mysql_backup` in `config/database.yml`, filled by `DatabaseBackupJob`) that boot-time `db:prepare` migrates alongside the primary. Restore a lost volume with `FROM=mysql_backup TO=primary bin/rails db:sync:copy`.
- Write migrations that are safe on MySQL, since they run there too: DDL is not transactional (a failure leaves it half-applied), and MySQL refuses to drop an index a foreign key still needs. CI passing on SQLite does not prove that; the `migrate-mysql` CI job runs migrations against MySQL.
- Never hand-edit `db/schema.rb`; generate it by running migrations.
- Production solid_cache/queue/cable use separate local SQLite files on the Docker volume (see `config/database.yml`).

## Git

- Work on a feature branch; do not commit directly to `main`.
- Commit messages: one terse line stating intent.
- PRs are squash-merged; title states what changed.
- Never commit secrets, `config/*.key`, `.env*`, `storage/`, `log/`, `tmp/`, or the spreadsheets at the repo root.
