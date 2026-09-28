require 'test_helper'

class MatchResultTest < ActiveSupport::TestCase
  test 'worked example splits match points 2-1' do
    result = MatchResult.new(matches(:fall_alpha_bravo))

    assert_equal 2, result.home_points
    assert_equal 1, result.away_points
    assert_equal 29, result.home_points_scored
    assert_equal 25, result.away_points_scored
  end

  test 'a sweep earns the season sweep bonus' do
    match = sweep_match(seasons(:fall))

    result = MatchResult.new(match)

    assert_in_delta(3.5, result.home_points)
    assert_equal 0, result.away_points
  end

  test 'a sweep earns a full point bonus in a season with sweep_bonus 1.0' do
    season = Season.create!(name: 'Legacy Season', starts_on: Date.new(2020, 1, 1), sweep_bonus: 1)
    RosterSpot.create!(season: season, team: teams(:alpha), player: players(:ada))
    RosterSpot.create!(season: season, team: teams(:alpha), player: players(:grace))
    RosterSpot.create!(season: season, team: teams(:bravo), player: players(:sam))
    RosterSpot.create!(season: season, team: teams(:bravo), player: players(:ben))
    match = sweep_match(season, MatchNight.create!(season: season, played_on: Date.new(2020, 1, 5), label: 'Week 1'))

    result = MatchResult.new(match)

    assert_equal 4, result.home_points
  end

  test 'is incomplete without every lineup finished' do
    match = matches(:fall_alpha_bravo)
    match.lineups.create!(position: 2)

    result = MatchResult.new(match)

    assert_not result.complete?
  end

  test 'winner is the team with more points' do
    assert_equal teams(:alpha), MatchResult.new(matches(:fall_alpha_bravo)).winner
  end

  test 'winner falls back to point differential when points tie' do
    match = matches(:fall_alpha_bravo)
    lineup = match.lineups.create!(position: 2)
    create_games!(lineup, [5, 11], [11, 7], [8, 11], players: second_lineup_players(seasons(:fall)))

    result = MatchResult.new(match.reload)

    assert_equal 3, result.home_points
    assert_equal 3, result.away_points
    assert_equal teams(:bravo), result.winner
  end

  private

  def second_lineup_players(season)
    home_two = Player.create!(first_name: 'Home', last_name: 'Two')
    home_three = Player.create!(first_name: 'Home', last_name: 'Three')
    away_two = Player.create!(first_name: 'Away', last_name: 'Two')
    away_three = Player.create!(first_name: 'Away', last_name: 'Three')
    RosterSpot.create!(season: season, team: teams(:alpha), player: home_two)
    RosterSpot.create!(season: season, team: teams(:alpha), player: home_three)
    RosterSpot.create!(season: season, team: teams(:bravo), player: away_two)
    RosterSpot.create!(season: season, team: teams(:bravo), player: away_three)
    [home_two, home_three, away_two, away_three]
  end

  def sweep_match(season, match_night = match_nights(:fall_week_one))
    match = Match.create!(season: season, match_night: match_night,
                          home_team: teams(:alpha), away_team: teams(:bravo))
    lineup = match.lineups.create!(position: 1)
    create_games!(lineup, [11, 4], [11, 6], [11, 8],
                  players: [players(:ada), players(:grace), players(:sam), players(:ben)])
    match.reload
  end

  def create_games!(lineup, *score_pairs, players:)
    home_a, home_b, away_a, away_b = players
    score_pairs.each_with_index do |(home_score, away_score), index|
      lineup.games.create!(number: index + 1, home_score: home_score, away_score: away_score,
                           home_player_a: home_a, home_player_b: home_b,
                           away_player_a: away_a, away_player_b: away_b)
    end
  end
end
