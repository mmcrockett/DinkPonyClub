# frozen_string_literal: true

# Run by the migrate-mysql CI job between db:fixtures:load and the rollback.
# Every `down` in the match-night set backfills row by row, so rolling back an
# empty database proves the DDL is ordered correctly but never executes a
# backfill body. These are the rows whose absence hid three bugs: each one made
# a `down` write a NULL into a column it then declares NOT NULL.
season = Season.first!

# No matches on this night, so its availability and slots cannot be keyed back
# to a match on the way down.
night = MatchNight.create!(season: season, played_on: Date.current + 30, label: 'Rollback edge case')
MatchAvailability.create!(match_night: night, player: Player.first!, status: 'in')
MatchSlot.create!(match_night: night, position: 1, starts_at: night.played_on.noon)

# No games on this lineup, so there are no players to restore to it.
Lineup.create!(match: Match.first!, position: 5)

puts "Seeded rollback edge cases on match_night #{night.id}"
