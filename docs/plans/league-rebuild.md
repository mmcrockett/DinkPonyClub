# League rebuild plan

Rebuild the features of PR #26 (`hudson2508-blip:codex/league-clubhouse`, a
React app storing each season as one JSON blob) natively on this app's
relational schema and Rails/Turbo/Stimulus stack. PR #26 stays open as the
reference prototype; branch `pr-26-clubhouse` is the fetched copy. Visual spec
is the set of screenshots taken from a locally seeded run of that branch.

Each numbered section below is one PR, handed to one agent. Sections list
their dependencies; anything not listed as a dependency can run in parallel.

## Decisions already made

Do not reopen these. They were settled with Mike on 2026-09-28.

| Topic | Decision |
|---|---|
| Frontend | Rails views + Turbo Frames + Stimulus + Tailwind. No React, no Node build. |
| Line players | Player ids move to `games` (`home_a/home_b/away_a/away_b`). `lineups` keeps only `position`. Supports 2- or 3-player lines with per-game pairs. |
| Sweep bonus / match points | Drop the cached `matches.*_match_points` / `*_points_scored` columns. Derive everything from `games` in query objects. Sweep bonus is per-season (`seasons.sweep_bonus`, decimal; Fall 2026 = 0.5, older seasons = 1). |
| Match night | New `match_nights` table. `matches.match_night_id` replaces `matches.played_on`. Two matchups on one night = one `match_night` row, two `matches`. |
| Availability | Re-key `match_availabilities` to `match_night_id`. Replace `playing` boolean with a 3-state `status` enum (`in`, `maybe`, `out`). Keep the noon-Central cutoff for players; captains and admins may edit any roster entry's availability at any time. Keep `match_slots` / `slot_availabilities` (start-time preferences) - re-keyed to `match_night_id` as well. |
| Captains | `roster_spots.captain` is the only source of truth. No hardcoded name list. |
| Draft rank | `roster_spots.draft_rank` string, captain/admin visibility only. Added in the schema PR, surfaced in the Elo PR. |
| Elo | Later PR, after stats. Port `app/services/clubhouse/ratings.rb` from `pr-26-clubhouse` reading from `games`. K=24, tier seeding, provisional under 12 games. |
| Photos | Later. Active Storage with the disk service on the Kamal `dink_pony_club_storage` volume. Never blobs in MySQL. |
| Fees, Announcements, Rules | Later. Not in wave 1. |
| Data cutover | One-off `bin/rails` task importing a clubhouse `Season` JSON export into the new tables. Harrison exports once from his live instance. |
| Placement | Sidebar entries per tab (Schedule, Standings, Stats, Players). Home keeps the next-match availability card. |
| PR #26 | Comment with a brief plan now; comment again as each wave-1 PR ships. Close after wave 1. |

## Conventions for every PR

- Branch from up-to-date `origin/main` in a worktree:
  `git worktree add -b <branch> .claude/worktrees/<slug> origin/main`.
- Minitest, fixtures in `test/fixtures/*.yml`, controller tests for every
  route, model tests for every validation and query object. System tests only
  where Stimulus behavior matters (see `test/system/availability_test.rb`).
- `bin/rubocop` and `bin/rails test` green before opening the PR. CI also runs
  `bin/brakeman` and `bin/importmap audit`.
- User-facing strings go in `config/locales/en.yml` under the controller key,
  matching the existing `availabilities.update.saved` pattern.
- Auth helpers already exist in `app/controllers/concerns/authentication.rb`:
  `require_sign_in`, `require_admin`, `current_player`, `admin?`. Add
  `require_captain_or_admin` in PR 1 and reuse it everywhere after.
- Sidebar links are declared in `app/helpers/navigation_helper.rb#sidebar_items`.
  Entries without `:path` render disabled - flip them to live links as each
  tab ships.
- Icons: `app/views/shared/_icon.html.erb`. Add new names there rather than
  inlining SVG.
- Tailwind theme colors `dpc-navy` and `dpc-green` are the palette. Match the
  existing `admin/players` and `home/_availability_card` look, not the
  clubhouse's; the screenshots are for information architecture and content,
  not pixel styling.
- Commit messages: one terse line. PR description ends with
  `<sub>🤖 assisted by claude</sub>`.

## Reference material on branch `pr-26-clubhouse`

| What | Where |
|---|---|
| Scorecard validation rules | `app/controllers/clubhouse/league_controller.rb#update_result` and `#valid_lineup?` |
| Elo algorithm and tests | `app/services/clubhouse/ratings.rb`, `test/services/clubhouse/ratings_test.rb` |
| Season JSON shape (import contract) | `clubhouse/lib/model.ts` (`Season`, `Match`, `Line`, `Player` types) and `app/services/clubhouse/import.rb` |
| Standings / stats derivation | `clubhouse/lib/model.ts` (`matchResult`, `standings`, `stats`) |
| Availability fan-out across same-night rounds | `league_controller.rb#update_availability` |
| Field visibility by role | `app/services/clubhouse/access.rb#serialize` |
| Screenshots | `~/obsidian/ClaudeCode/dinkponyclub-league-screenshots/01-schedule.png` ... `12-import-dialog.png` on Mike's machine. Not in the repo: they show roster emails and this repo is public. Ask Mike if you cannot read them. |

---

## PR 1 - Schema: match nights, per-game players, derived scoring

**Depends on:** nothing. Everything else depends on this.

**Goal:** land every schema decision in one migration set so later PRs never
touch `db/`. No UI changes. Existing tests updated to the new shape.

### Migrations

1. `create_match_nights`
   - `season_id` (fk, not null), `played_on` date not null, `label` string(60)
     not null (e.g. "Week 3", "Semifinal"), `venue` string(150), `notes` text,
     `canceled` boolean default false not null, timestamps.
   - Index `[season_id, played_on]`.
2. `move_matches_to_match_nights`
   - Add `matches.match_night_id` (fk, not null after backfill). Backfill: one
     `match_night` per distinct `(season_id, played_on)`, `label` = "Week N"
     by chronological order within season. Then drop `matches.played_on` and
     its index.
   - Drop `home_match_points`, `away_match_points`, `home_points_scored`,
     `away_points_scored`.
3. `move_lineup_players_to_games`
   - Add to `games`: `home_player_a_id`, `home_player_b_id`,
     `away_player_a_id`, `away_player_b_id` (all fk to players, not null after
     backfill). Backfill from the parent lineup's four columns.
   - Drop the four `lineups.*_player_*_id` columns and their indexes.
4. `rekey_availability_to_match_nights`
   - `match_availabilities`: add `match_night_id`, backfill via
     `matches.match_night_id`, drop `match_id`, add `status` string(10)
     default `'maybe'` not null, backfill `playing ? 'in' : 'out'`, drop
     `playing`. Unique index `[match_night_id, player_id]`.
   - `match_slots`: add `match_night_id`, backfill, drop `match_id`. Unique
     `[match_night_id, position]`.
5. `add_league_settings`
   - `seasons.sweep_bonus` decimal(3,1) default 0.5 not null.
   - `seasons.rules` text (nullable; used in a later PR, cheap to add now).
   - `roster_spots.draft_rank` string(10).
   - `players.phone` string(40) and `players.contact_email` string(254)
     (self-editable contact details, distinct from the sign-in `email`).

Local dev DB is sqlite, production is MySQL - write migrations that work on
both (no sqlite-only `ALTER`, use `change_table` with `bulk: true` where
helpful).

### Models

- New `MatchNight`: `belongs_to :season`, `has_many :matches`,
  `has_many :match_availabilities`, `has_many :match_slots`.
  Scopes `chronological` (by `played_on`), `upcoming`. Method
  `availability_cutoff_at` (noon Central on `played_on`) and
  `availability_open?` move here from `Match`.
  `Match::AVAILABILITY_CUTOFF_HOUR` moves with them.
- `Match`: `belongs_to :match_night`; `delegate :season, :played_on, to: :match_night`
  (keep `season_id` column for query convenience but validate it equals the
  night's). Remove `recalculate_score!`, `point_differential`, `winner`
  (replaced by the `MatchResult` query object below). Keep `complete?`.
- `Lineup`: drop the four `belongs_to :*_player_*`, `home_players`,
  `away_players`, `players`, and the three player validations. Keep
  `position` uniqueness and `GAMES_PER_LINEUP`. Remove `SWEEP_BONUS`
  (now on Season).
- `Game`: add four `belongs_to` player associations. Validations:
  players distinct within the game; home players rostered on the match's home
  team for the season, away likewise; a player appears on only one line per
  match (check across sibling lineups' games). Remove the
  `recalculate_match_score` callbacks. Keep the 11 / win-by-2 rule but make
  it a season setting only if the import (PR 2) proves real data violates it -
  do not pre-emptively relax.
- `MatchAvailability`: `belongs_to :match_night`, `enum :status,
  { in: 'in', maybe: 'maybe', out: 'out' }`.
- `MatchSlot`: `belongs_to :match_night`.
- `Season`: `has_many :match_nights`. Remove the `Standing` struct and
  `standings` method (moved to query object).
- `Player#next_match(season)` becomes `next_match_night(season)` returning
  the next `MatchNight` where any of the player's team's matches are.

### Query objects (`app/models/` or `app/queries/`, plain Ruby)

- `MatchResult.new(match)` - `home_points`, `away_points` (game wins plus
  `season.sweep_bonus` per 3-0 line), `home_points_scored`,
  `away_points_scored`, `winner`, `complete?`. This is the single place the
  scoring rule lives.
- `Standings.new(season)` - array of `Standings::Row(team, played, wins,
  losses, ties, points_for, points_against, diff)` sorted by wins desc, then
  diff desc. Regular season only (exclude nights whose label matches
  `/semi|final/i` - or add `match_nights.playoff` boolean; pick the boolean).
- `PlayerStats.new(season)` - per rostered player: games, wins, losses,
  win_pct, sweep_bonus_count, points. Computed from `games` rows the player
  appears in.

### Auth

- Add `require_captain_or_admin` to `Authentication`:
  admin, or `current_player` has a `roster_spots.captain` row in the season
  in question. Add `captain_in?(season)` on `Player`.

### Tests to update / add

- All fixtures: `match_nights.yml` new; `matches.yml` drops `played_on` and
  points, gains `match_night`; `lineups.yml` drops players; `games.yml` gains
  four players; `match_availabilities.yml` and `match_slots.yml` re-key.
- `test/models/match_test.rb`, `lineup_test.rb`, `game_test.rb`,
  `season_test.rb`, `match_availability_test.rb`, `match_slot_test.rb`,
  `player_test.rb` - update to the new shape.
- New: `match_night_test.rb`, `match_result_test.rb` (2-0, 3-0 sweep with
  0.5 and 1.0 bonus, incomplete), `standings_test.rb`, `player_stats_test.rb`.
- `home_controller_test.rb`, `availabilities_controller_test.rb`,
  `test/system/availability_test.rb`: adjust to `match_night` routing.

### Acceptance

- `bin/rails db:migrate` clean on a fresh sqlite DB and on a DB carrying the
  current fixtures' shape.
- `bin/rails test` green, `bin/rubocop` clean.
- Home page availability card still works against the re-keyed tables (route
  becomes `PATCH /match_nights/:match_night_id/availability`).

---

## PR 2 - Cutover importer

**Depends on:** PR 1.

**Goal:** `bin/rails league:import_snapshot[path/to/fall-2026.json]` loads a
clubhouse `Season` JSON export into the new tables. Idempotent by season
name: re-running on an existing season is refused unless `FORCE=1`, in which
case it deletes that season's nights/matches/games/availabilities first
(never players or accounts).

### Mapping

| Clubhouse JSON | Rails |
|---|---|
| `name`, `archived` | `Season` (find or create by name); `sweep_bonus` = 1.0 if `archived`, else 0.5; `starts_on`/`ends_on` from min/max `weeks[].date` |
| `teams[]` | `Team` find or create by name |
| `players[]` (`team != "SUBS"`) | `Player` matched by `email` (downcased), else by `first_name`/`last_name` split on last space, else created with `status: 'active'` and no email. `RosterSpot(season, team, player, captain: false, draft_rank: rank)` |
| `players[]` with `team == "SUBS"` | `Player` only, no `RosterSpot`. Warn in the summary. |
| `players[].phone`, `contactEmail` | `players.phone`, `players.contact_email` (only if blank) |
| `weeks[]` | `MatchNight(label, played_on: date, venue, notes: time)`. Weeks sharing a `date` merge into one night. `playoff: true` when label matches `/semi|final/i`. |
| `matches[]` with `a`/`b` not `"TBD"` | `Match(match_night, home_team: a, away_team: b)` |
| `matches[].lines[]` | `Lineup(position: line)` |
| `lines[].scores[g]` where both non-null | `Game(number: g+1, home_score, away_score, players...)` with pair rotation: 2 players -> same pair every game; 3 players -> `[P1,P2]`, `[P1,P3]`, `[P2,P3]` for games 1..3 (matches `Ratings` in the clubhouse) |
| `players[].availability{weekId: status}` | `MatchAvailability(match_night, player, status)` mapping `yes`->`in`, `no`->`out`, `maybe`->`maybe`, `unknown`->skip |
| `announcements`, `rules`, `paid/shirt/hat` | **ignored** in wave 1 (rules -> `seasons.rules` is fine to include since the column exists) |

Captains: after import, print the roster and instruct the operator to set
`captain: true` via the existing admin UI or a follow-up console line - the
clubhouse's captain list is hardcoded in `access.rb`, not in the JSON.

### Output

Summary to stdout: seasons/teams/players created vs matched, roster spots,
nights, matches, lineups, games, availabilities, and a **warnings** list
(unmatched names, SUBS entries, games that fail `Game#final_score`, lines with
fewer than 2 players). Non-zero exit on any hard failure; warnings do not
fail.

### Tests

- `test/tasks/league_import_test.rb` (or `test/lib/`) with a small fixture
  JSON under `test/fixtures/files/clubhouse_season.json` covering: 2 teams,
  one 3-player line with rotation, one 2-player line, one partial line, a SUBS
  entry, same-date semifinal + final, availability mapping. Assert counts and
  a spot-check of the rotation pairs on games 1..3.

### Acceptance

- Task runs against the fixture and against a real export Mike supplies
  locally (not committed).
- Re-run without `FORCE` refuses; with `FORCE` produces identical counts.

---

## PR 3 - Schedule tab and availability

**Depends on:** PR 1. Parallel with PR 2 and PR 4.

**Goal:** `/schedule` lists the current season's match nights with matchups
and results, lets a player set in/maybe/out per night, and lets captains and
admins see and set team-wide availability. Screenshots `01-schedule.png`,
`02-schedule-team-availability.png`.

### Routes

    resources :match_nights, only: %i[index show] , path: 'schedule'
    patch 'schedule/:match_night_id/availability', to: 'availabilities#update'   # moved from PR 1's interim route
    patch 'schedule/:match_night_id/availability/:player_id', to: 'availabilities#update_for_player'  # captain/admin

Season selection via `?season=<id>` param defaulting to `Season.current.first
|| Season.chronological.last`; same helper reused by Standings/Stats/Players -
put it in a `SeasonScoped` controller concern.

### Views

- `match_nights/index.html.erb`: one card per night (partial
  `_match_night.html.erb`): date block, label, venue, notes, `Canceled` state,
  "Up next" marker on the first night with `played_on >= today`, `Final` /
  `Playoffs` / `Scheduled` pill; each match as a row with team names and
  either `home-away` points from `MatchResult` or "vs". Availability segmented
  control (In / Maybe / Out) per night, disabled with a note when
  `availability_open?` is false and the viewer is not captain/admin.
- Right rail (`_next_up.html.erb`): next night's matchups and a
  "Weeks completed" count; a night is complete when every match is complete.
- Team availability toggle (Turbo Frame swap, captain/admin only): per team,
  per night, count of in/maybe and each rostered player's status as a
  `<select>` posting to `update_for_player`.
- Keep `home/_availability_card.html.erb` working; it now links to
  `/schedule`.

### Stimulus

- Reuse `availability_controller.js` for the segmented control; extend rather
  than duplicate.

### Tests

- `match_nights_controller_test.rb`: index renders nights in order, marks up
  next, hides team-availability for non-captains, shows it for captains/admin.
- `availabilities_controller_test.rb`: player can set own status before
  cutoff, refused after; captain can set teammate after cutoff; captain cannot
  set a player on another team (admin can).
- System test: segmented control updates without full reload.

### Acceptance

- Sidebar "Schedule" entry becomes a live link.
- Matches the information architecture of screenshots 01 and 02.

---

## PR 4 - Scorecards (captain result entry)

**Depends on:** PR 1. Parallel with PR 2 and PR 3.

**Goal:** captains of either team in a match (and admins) enter or edit the
match's 5 lines x 3 games with 2 or 3 players per side. Screenshot
`11-scorecard-dialog.png`.

### Routes

    resources :matches, only: %i[show edit update]   # show = read-only scorecard, edit/update = captain/admin

### Form object

`ScorecardForm` (ActiveModel) wrapping a `Match`. Attributes per line 1..5:
`home_players` (2-3 ids), `away_players` (2-3 ids), `scores` (3 pairs, blanks
allowed for unplayed games). Rules, all from the clubhouse's `update_result`:

- Every line needs at least the first two players per side.
- No player on both sides of a line; no player on two lines in the match.
- Every player rostered on their side's team for the season.
- Any game with both scores present must satisfy `Game` validations (no ties,
  11 / win-by-2 unless PR 2 forced a change).
- 3 players -> games 1..3 use pairs `[1,2]`, `[1,3]`, `[2,3]`; 2 players ->
  same pair each game. The form derives per-game player ids; the UI never asks
  for pairs directly.
- Save is one transaction: replace the match's lineups/games wholesale.

### Views

- `matches/show`: read-only scorecard, line by line, team columns, 3 game
  scores, per-line result.
- `matches/edit`: same layout with `<select>`s for players (rostered players
  only, grouped by team) and number inputs for scores. Footnote text from the
  clubhouse: "Three players rotate P1/P2, P1/P3, P2/P3. Two players play all
  three games."
- Schedule cards (PR 3) link "Enter results" / "Scorecard" per match for
  captains/admins; non-captains see the score only.

### Tests

- `scorecard_form_test.rb`: every rule above, plus a full valid save and a
  3-player rotation asserting the pairs on games 1..3.
- `matches_controller_test.rb`: non-captain gets 302 on edit/update;
  captain of home team can save; captain of an uninvolved team cannot; admin
  can.

### Acceptance

- A captain can post a full result from the browser and the Standings (PR 5)
  reflect it with no cache to bust.

---

## PR 5 - Standings tab

**Depends on:** PR 1. Small. Parallel with 3 and 4.

**Goal:** `/standings` renders `Standings.new(season)`. Screenshot
`03-standings.png`.

- Podium cards for the top 3, then the full table: Rank, Team, Played, W, L,
  T, Points for, Points against, Diff.
- "N results posted" pill = count of complete regular-season matches.
- Footnote: "Every game win is one point; a three-game line sweep adds
  <sweep_bonus>."
- Sidebar "Standings" goes live.
- Controller test: order, tie handling, playoff nights excluded.

---

## PR 6 - Season stats tab

**Depends on:** PR 1. Parallel with 3, 4, 5.

**Goal:** `/stats` renders `PlayerStats.new(season)`. Screenshot
`04-season-stats.png` (ignore the Elo / Draft rank columns and the Lifetime
option - those are PR 8).

- Filters (GET params, Turbo Frame): search by name, team (incl. a
  "Substitutes" bucket for players who appear in games but have no roster
  spot), hide-substitutes checkbox, sort by name / win% desc / win% asc / team.
- Columns: Player, Team, Games, Wins, Losses, Win %, Sweep bonus, Points.
  Players with zero games show "-" for win% and sort last.
- Sidebar "Stats" goes live (rename the existing disabled "Standings"/"Players"
  placeholders as needed; add a "Stats" entry with a `chart` icon).
- Controller test per filter and sort.

---

## PR 7 - Players tab and profile edit

**Depends on:** PR 1. Parallel with 3-6.

**Goal:** `/players` directory and self-service contact edit. Screenshot
`05-players.png`.

- Cards: initials avatar, name, team, `Captain` pill, Win rate, Games (from
  `PlayerStats`). Contact email / phone shown only to captains/admins;
  everyone else sees "Contact details are available to captains."
- Filters: search, team, hide substitutes, sort name / win% / team (reuse the
  PR 6 filter partial - coordinate on a shared `_stats_filters.html.erb`).
- "View profile" -> `players/:id` (public card + this season's line
  results). "Edit profile" -> own player only (or admin) editing
  `players.phone` and `players.contact_email`. Sign-in `email` is admin-only,
  via the existing `admin/players` form.
- Sidebar "Players" goes live.
- Tests: visibility of contacts by role; a player cannot edit another's
  profile; admin can.

---

## PR 8 - Elo and draft rank (wave 2)

**Depends on:** PR 6, PR 7, PR 2 (needs real history to be meaningful).

**Goal:** port `Clubhouse::Ratings` to read `games` across all seasons; add
Elo and Draft rank columns/filters to Stats and Players for captains/admins;
add a Lifetime view to Stats.

- `LeagueRating.new(seasons)` service: chronological over all complete games;
  seed each player once from their earliest `draft_rank` tier (4-line seasons
  1650/1550/1450/1350, 5-line 1700/1600/1500/1400/1300; A-D map to lines 1-4;
  fall back to first line played; else 1500); K=24; pair-average rating per
  game; ties ignored; `provisional` when under 12 rated games. Port the
  existing `ratings_test.rb` cases.
- Stats: "League Elo" and "Draft rank" columns, `Elo desc` sort, draft-rank
  filter, "Lifetime" option in the season picker (all seasons, adds a Ties
  column). Players cards: Elo and Draft rank tiles. All gated by
  captain/admin.
- "About player ratings" info panel text from `league.tsx` (search for "About
  player ratings").
- No name-alias JSON: the importer (PR 2) already resolves identity to
  `players.id`.

---

## Wave 2 backlog (not scheduled)

Each is a small standalone PR once wave 1 is on `main`.

- **Announcements** - `announcements(season_id, title, body, posted_at)`,
  admin create, list newest first. Screenshot `07-announcements.png`.
- **Fees** - `roster_spots` columns `league_fee_paid`, `shirt_ordered`,
  `shirt_paid`, `hat_ordered`, `hat_paid`; Venmo deep link; admin roll-up.
  Screenshot `08-fees.png`.
- **Rules & format** - `seasons.rules` (column exists after PR 1), format
  tiles derived from data. Screenshot `09-rules-format.png`.
- **Photos** - Active Storage disk service on `/rails/storage`, member
  upload with client-side resize (port the canvas code from
  `clubhouse/photos.tsx`), uploader-or-admin delete. Screenshot `06-photos.png`.
- **Admin schedule editing** - CRUD for `match_nights` and matchup team
  assignment (the clubhouse's "Edit" per week). Teams locked once a match has
  games.
- **Home page** - replace the hardcoded August 2026 bracket in
  `home/index.html.erb` with a rendered playoff bracket from `match_nights`
  flagged `playoff`.

## PR #26 comments

Post on PR #26 when this plan merges, and again as PRs 3, 4, 5, 6, 7 land.
Keep each to a few lines; link the merged PR. Close #26 after PR 7.
