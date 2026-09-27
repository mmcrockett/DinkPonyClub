require 'test_helper'

class MatchTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate matches(:fall_alpha_bravo), :valid?
  end

  test 'saving a game recalculates the cached match score' do
    match = matches(:fall_alpha_bravo)
    lineups(:fall_alpha_bravo_one).games.find_by!(number: 1).update!(home_score: 15, away_score: 4)

    match.reload

    assert_equal 2, match.home_match_points
    assert_equal 1, match.away_match_points
    assert_equal 33, match.home_points_scored
  end

  test 'winner is the team with more match points' do
    assert_equal teams(:alpha), matches(:fall_alpha_bravo).winner
  end

  test 'winner falls back to point differential when match points tie' do
    match = Match.new(home_team: teams(:alpha), away_team: teams(:bravo), home_match_points: 2,
                      away_match_points: 2, home_points_scored: 30, away_points_scored: 20)

    assert_equal teams(:alpha), match.winner
  end

  test 'winner is nil when points and differential both tie' do
    match = Match.new(home_team: teams(:alpha), away_team: teams(:bravo), home_match_points: 2,
                      away_match_points: 2, home_points_scored: 25, away_points_scored: 25)

    assert_nil match.winner
  end

  test 'destroying a match cascades through lineups to games' do
    match = matches(:fall_alpha_bravo)

    assert_difference('Lineup.count' => -1, 'Game.count' => -3) do
      match.destroy
    end
  end

  test 'availability is open before noon central on match day' do
    match = matches(:fall_future)

    travel_to match.played_on.in_time_zone.change(hour: 11, min: 59) do
      assert_predicate match, :availability_open?
    end
  end

  test 'availability closes at noon central on match day' do
    match = matches(:fall_future)

    travel_to match.played_on.in_time_zone.change(hour: 12, min: 1) do
      assert_not match.availability_open?
    end
  end

  test 'availability is closed the day after the match' do
    match = matches(:fall_future)

    travel_to match.played_on.in_time_zone.change(hour: 11) + 1.day do
      assert_not match.availability_open?
    end
  end

  test 'availability is closed when there is no played_on date' do
    match = Match.new(season: seasons(:fall), home_team: teams(:alpha), away_team: teams(:bravo))

    assert_not match.availability_open?
  end
end
