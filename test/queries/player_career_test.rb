require 'test_helper'

class PlayerCareerTest < ActiveSupport::TestCase
  test 'one row per season the player is rostered in, oldest first' do
    rows = PlayerCareer.new(players(:ada)).rows

    assert_equal [seasons(:spring), seasons(:fall)], rows.map(&:season)
    assert_equal [teams(:alpha), teams(:alpha)], rows.map(&:team)
  end

  test 'carries each season record' do
    spring, fall = PlayerCareer.new(players(:ada)).rows

    assert_equal [0, nil], [spring.games, spring.win_pct]
    assert_equal [3, 2, 1], [fall.games, fall.wins, fall.losses]
  end

  test 'totals add up across seasons' do
    totals = PlayerCareer.new(players(:ada)).totals

    assert_equal [3, 2, 1], [totals.games, totals.wins, totals.losses]
    assert_in_delta 2.0 / 3, totals.win_pct
  end

  test 'a substitute with games but no roster spot gets a substitute row' do
    substitute = Player.create!(first_name: 'Sub', last_name: 'Stitute')
    add_won_lineup(home: [players(:ada), substitute])

    rows = PlayerCareer.new(substitute).rows

    assert_equal [seasons(:fall)], rows.map(&:season)
    assert_predicate rows.first, :substitute?
    assert_equal 3, rows.first.wins
  end

  test 'a player with no seasons has no rows and zero totals' do
    career = PlayerCareer.new(Player.create!(first_name: 'New', last_name: 'Comer'))

    assert_empty career.rows
    assert_equal 0, career.totals.games
  end

  private

  def add_won_lineup(home:)
    match = Match.create!(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                          home_team: teams(:alpha), away_team: teams(:bravo))
    lineup = match.lineups.create!(position: 2)
    3.times do |index|
      lineup.games.create!(number: index + 1, home_score: 11, away_score: 5,
                           home_player_a: home.first, home_player_b: home.last,
                           away_player_a: players(:sam), away_player_b: players(:ben))
    end
  end
end
