require 'test_helper'

class PlayerStatsTest < ActiveSupport::TestCase
  test 'computes games, wins, losses, and win_pct from the fixture games' do
    row = PlayerStats.new(seasons(:fall)).rows.find { |candidate| candidate.player == players(:ada) }

    assert_equal 3, row.games
    assert_equal 2, row.wins
    assert_equal 1, row.losses
    assert_in_delta(2.0 / 3, row.win_pct)
  end

  test 'a player with no games has a nil win_pct' do
    bench_player = Player.create!(first_name: 'Bench', last_name: 'Player')
    RosterSpot.create!(season: seasons(:fall), team: teams(:alpha), player: bench_player)

    row = PlayerStats.new(seasons(:fall)).rows.find { |candidate| candidate.player == bench_player }

    assert_equal 0, row.games
    assert_nil row.win_pct
  end

  test 'a sweep counts toward sweep_bonus_count and points' do
    match = Match.create!(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                          home_team: teams(:alpha), away_team: teams(:bravo))
    lineup = match.lineups.create!(position: 2)
    lineup.games.create!(number: 1, home_score: 11, away_score: 4,
                         home_player_a: players(:ada), home_player_b: players(:grace),
                         away_player_a: players(:sam), away_player_b: players(:ben))
    lineup.games.create!(number: 2, home_score: 11, away_score: 6,
                         home_player_a: players(:ada), home_player_b: players(:grace),
                         away_player_a: players(:sam), away_player_b: players(:ben))
    lineup.games.create!(number: 3, home_score: 11, away_score: 8,
                         home_player_a: players(:ada), home_player_b: players(:grace),
                         away_player_a: players(:sam), away_player_b: players(:ben))

    row = PlayerStats.new(seasons(:fall)).rows.find { |candidate| candidate.player == players(:ada) }

    assert_equal 1, row.sweep_bonus_count
    assert_equal(5 + 0.5, row.points)
  end

  test 'reports sweep bonus points using the season bonus' do
    add_lineup(position: 2, home: [players(:ada), players(:grace)], away: [players(:sam), players(:ben)])

    row = row_for(players(:ada))

    assert_equal 1, row.sweep_bonus_count
    assert_in_delta 0.5, row.sweep_bonus_points
  end

  test 'a player with games but no roster spot is a substitute row' do
    substitute = Player.create!(first_name: 'Sub', last_name: 'Stitute')
    add_lineup(position: 2, home: [players(:ada), substitute], away: [players(:sam), players(:ben)])

    row = row_for(substitute)

    assert_predicate row, :substitute?
    assert_nil row.team
    assert_equal 3, row.games
    assert_equal 3, row.wins
  end

  test 'rostered players are not substitutes' do
    assert_not_predicate row_for(players(:ada)), :substitute?
  end

  test 'query count does not grow with players or games' do
    baseline = count_queries { PlayerStats.new(seasons(:fall)).rows }

    extra = [1, 2].map do |n|
      Player.create!(first_name: "Extra#{n}", last_name: 'Player').tap do |player|
        RosterSpot.create!(season: seasons(:fall), team: n == 1 ? teams(:alpha) : teams(:bravo), player: player)
      end
    end
    add_lineup(position: 2, home: [players(:ada), extra.first], away: [players(:sam), extra.last])
    add_lineup(position: 3, home: [players(:grace), Player.create!(first_name: 'Sub', last_name: 'One')],
               away: [players(:ben), Player.create!(first_name: 'Sub', last_name: 'Two')])

    assert_equal(baseline, count_queries { PlayerStats.new(seasons(:fall)).rows })
  end

  private

  def row_for(player)
    PlayerStats.new(seasons(:fall)).rows.find { |candidate| candidate.player == player }
  end

  def add_lineup(position:, home:, away:)
    match = Match.create!(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                          home_team: teams(:alpha), away_team: teams(:bravo))
    lineup = match.lineups.create!(position: position)
    3.times do |index|
      lineup.games.create!(number: index + 1, home_score: 11, away_score: 5,
                           home_player_a: home.first, home_player_b: home.last,
                           away_player_a: away.first, away_player_b: away.last)
    end
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end
