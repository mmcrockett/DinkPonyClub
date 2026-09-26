# League clubhouse

The league app is available at `/clubhouse`, linked from Home. It runs inside Rails with the existing Google OAuth session. Vite builds the React interface; no Node process, Cloudflare account, or ChatGPT authentication is required in production.

## Run locally

Use the repository's Ruby version and Node 22.13 or later:

```sh
bundle install
npm --prefix clubhouse ci
npm --prefix clubhouse run build
bin/rails db:migrate
bin/dev
```

Rebuild the frontend after edits. The Dockerfile builds it automatically during deployment. Keep `/clubhouse-assets` behind the same origin as Rails; the frontend sends Rails CSRF tokens with every write.

## Initial data import

1. Back up the existing site's database and the live league app before migrating data.
2. Create/verify player accounts using the existing Admin Players page. Grant organizer admin status through the site's existing administration process.
3. Obtain private JSON season snapshots from the live league database, including the current saved revision. The source workbook imports alone will not include later availability, profile, fee, or result edits.
4. Sign in as an administrator and visit `/clubhouse/setup`. Upload one season object or an array of season objects (maximum 2 MB). Choose the active season ID, currently `fall-2026`.
5. Confirm all eight captains have matching login email addresses and verify member access before inviting the league.

The importer accepts the `Season` structure in `clubhouse/lib/model.ts`. It matches login emails to existing Rails player IDs and ignores supplied `accountId` and captain flags. Accounts are never created or elevated by imports. Unmatched people remain in statistics, but cannot sign in as that roster entry. To link an account created after import, an organizer can edit that player's login email in the clubhouse profile. Contact email is separate from the sign-in identity.

Imports create new season IDs and refuse to overwrite existing records. The active season controls permissions. Spring and Summer should have `archived: true`; archived views are read-only. Do not commit private exports, contacts, draft ranks, payment statuses, or availability to GitHub. `/private-imports` is ignored by Git and Docker.

## Storage and existing features

`ClubhouseSeason` stores validated season snapshots in the Rails database. Snapshot storage preserves the imported historical standings and source statistics alongside raw scorecards, three-player rotations, and half-point sweep bonuses. Updates use Active Record optimistic locking to reject stale saves.

The existing `Season`, `Match`, `Lineup`, and `Game` tables and historical Rails pages remain independent. This PR does not copy snapshot match results into those tables or change the existing Home playoff display. The clubhouse is the authoritative workflow for its imported schedules, results, fees, and availability. A future normalization migration should preserve the archived source summaries and use decimal match points.

Open PR #24 adds a separate home-page availability workflow with a noon match-day cutoff. Before enabling both workflows, choose one data model and cutoff policy and connect the other view to it. This clubhouse retains the requested ability to update availability throughout the season. The new Home link is deliberately small to limit conflicts with sidebar PR #25.

Photos are stored in the primary database with an 8 MB limit. Both original bytes and metadata require an active league member session; only the uploader or organizer can delete a photo. Database backups therefore include photos; allow for their storage growth. The browser resizes uploads and strips image metadata. The server checks file signatures and serves only JPEG/PNG/WebP types.

## Permissions

- Active Rails accounts must be linked to the current roster (or be an organizer) to access the API.
- Players edit their own contact details and availability. Captains edit any roster entry's availability through Team availability.
- Only current captains enter results and open scorecards in the interface.
- Other players' contacts, draft ranks, and Elo fields are omitted from non-captain API responses, including lifetime views. Own payment details remain visible; organizers see and confirm all payments.
- Fall captain access is limited to Harrison Hudson, Jordan Blount, Aabir Malik, Chris Bell, Justin Browne, Mike Crockett, Brooks Masterson, and Jon Berry, linked to Rails accounts by the organizer's imported roster. Later seasons use existing Rails `RosterSpot` captain assignments matching the season name.
- Fees remain $50, shirts $30, hats $35, paid directly to `@hudson2508`. Confirmation is manual; no payment processing is introduced.

## Ratings and validation

Elo processes complete scorecards in date order across seasons, uses the actual two players in each game, seeds each identity once from its earliest draft tier or first played line, and uses K=24. Historical Elo stops at the selected season's end. Lifetime records use raw completed games. Verified name aliases are retained. These are league ratings, not DUPR.

```sh
npm --prefix clubhouse run typecheck
npm --prefix clubhouse run build
bin/rails test
bin/rubocop
```

Ruby/TypeScript calculation parity was checked locally against all three private source seasons; the public tests use synthetic players. Deployment and live private-data import are separate from this code review.
