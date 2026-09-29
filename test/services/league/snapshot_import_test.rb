require 'test_helper'

module League
  class SnapshotImportTest < ActiveSupport::TestCase
    setup do
      @data = JSON.parse(file_fixture('clubhouse_season.json').read)
    end

    test 'creates the season with the archived sweep bonus and week date range' do
      SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')

      assert_in_delta(1.0, season.sweep_bonus)
      assert_equal Date.new(2025, 3, 5), season.starts_on
      assert_equal Date.new(2025, 4, 16), season.ends_on
    end

    test 'creates the two teams' do
      SnapshotImport.new(@data).call

      assert_equal ['Import Kings', 'Import Rays'],
                   Team.where(name: ['Import Rays', 'Import Kings']).order(:name).pluck(:name)
    end

    test 'matches existing players by email and by name, and creates the rest' do
      before = Player.count

      SnapshotImport.new(@data).call

      assert_equal players(:ada), Player.find_by(email: 'ada@example.test')
      assert_equal players(:grace), Player.find_by(first_name: 'Grace', last_name: 'Fixture')
      assert_equal players(:sam), Player.find_by(first_name: 'Sam', last_name: 'Placeholder')
      assert_equal players(:ben), Player.find_by(first_name: 'Ben', last_name: 'Stubfield')
      assert_equal 7, Player.count - before
    end

    test 'creates roster spots with draft rank and marks captains from the JSON flag' do
      SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')
      ada_spot = RosterSpot.find_by(season: season, player: players(:ada))

      assert_equal '1A', ada_spot.draft_rank
      assert_predicate ada_spot, :captain?
      assert_not RosterSpot.find_by(season: season, player: players(:grace)).captain?
    end

    test 'imports the SUBS entry as a player with no roster spot and a warning' do
      report = SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')
      sub = Player.find_by(first_name: 'sub@example.test')

      assert_not_nil sub
      assert_nil RosterSpot.find_by(season: season, player: sub)
      assert(report.warnings.any? { |message| message.include?('SUBS') })
    end

    test 'merges same-date weeks into one playoff night' do
      SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')
      playoff_night = season.match_nights.find_by(played_on: Date.new(2025, 4, 16))

      assert_equal 2, season.match_nights.count
      assert_predicate playoff_night, :playoff?
      assert_equal 'Semifinal / Final', playoff_night.label
    end

    test 'rotates a 3-player line through the three pair slots' do
      SnapshotImport.new(@data).call

      pairs = rays_lineup(1).games.order(:number).map do |game|
        [game.home_player_a.full_name, game.home_player_b.full_name]
      end

      assert_equal [['Ada Testerson', 'Grace Fixture'], ['Ada Testerson', 'New Rays One'],
                    ['Grace Fixture', 'New Rays One']], pairs
    end

    test 'plays a 2-player line with the same pair every game' do
      SnapshotImport.new(@data).call

      pairs = rays_lineup(2).games.order(:number).map do |game|
        [game.home_player_a.full_name, game.home_player_b.full_name]
      end

      assert_equal [pairs.first] * 3, pairs
    end

    test 'imports a partial line as two games, not three' do
      SnapshotImport.new(@data).call

      assert_equal 2, semifinal_match.lineups.sole.games.count
    end

    test 'imports an out-of-range score with a warning instead of rejecting it' do
      report = SnapshotImport.new(@data).call

      game = semifinal_match.lineups.sole.games.find_by(number: 1)

      assert_equal [9, 7], [game.home_score, game.away_score]
      assert(report.warnings.any? { |message| message.include?('9') && message.include?('win by 2') })
    end

    test 'skips a line with fewer than two players on a side' do
      report = SnapshotImport.new(@data).call

      assert(report.warnings.any? { |message| message.include?('fewer than 2 players') })
      assert_equal 0, final_match.lineups.count
    end

    test 'skips a line naming a player absent from players[]' do
      report = SnapshotImport.new(@data).call

      assert(report.warnings.any? { |message| message.include?('Unknown Player') })
    end

    test 'maps availability statuses and skips unknown' do
      SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')
      first_night = season.match_nights.find_by(played_on: Date.new(2025, 3, 5))
      second_night = season.match_nights.find_by(played_on: Date.new(2025, 4, 16))

      assert_equal 'in', MatchAvailability.find_by(match_night: first_night, player: players(:ada)).status
      assert_equal 'maybe', MatchAvailability.find_by(match_night: second_night, player: players(:ada)).status
    end

    test 'resolves a merged-night availability collision to the later week' do
      SnapshotImport.new(@data).call

      season = Season.find_by(name: 'Spring 2025')
      second_night = season.match_nights.find_by(played_on: Date.new(2025, 4, 16))

      assert_equal 'out', MatchAvailability.find_by(match_night: second_night, player: players(:grace)).status
    end

    test 'refuses to re-import an existing season without FORCE' do
      SnapshotImport.new(@data).call

      error = assert_raises(SnapshotImport::Error) { SnapshotImport.new(@data).call }

      assert_match(/already exists/, error.message)
      assert_equal 1, Season.where(name: 'Spring 2025').count
    end

    test 'a forced re-import yields identical counts and preserves a hand-set captain' do
      SnapshotImport.new(@data).call
      season = Season.find_by(name: 'Spring 2025')
      ben_spot = RosterSpot.find_by(season: season, player: players(:ben))
      ben_spot.update!(captain: true)

      report = SnapshotImport.new(@data, force: true).call

      assert_equal 8, report.count(:games)
      assert_predicate ben_spot.reload, :captain?
    end

    private

    def rays_lineup(position)
      Match.joins(:season).find_by(seasons: { name: 'Spring 2025' }, home_team: Team.find_by(name: 'Import Rays'))
           .lineups.find_by(position: position)
    end

    def playoff_night_matches
      Match.joins(:season, :match_night)
           .where(seasons: { name: 'Spring 2025' }, match_nights: { played_on: Date.new(2025, 4, 16) })
           .order(:id)
    end

    def semifinal_match
      playoff_night_matches.first
    end

    def final_match
      playoff_night_matches.second
    end
  end
end
