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
end
