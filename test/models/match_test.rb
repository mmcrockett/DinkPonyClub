require 'test_helper'

class MatchTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate matches(:fall_alpha_bravo), :valid?
  end

  test 'played_on delegates to the match night' do
    assert_equal match_nights(:fall_week_one).played_on, matches(:fall_alpha_bravo).played_on
  end

  test 'destroying a match cascades through lineups to games' do
    match = matches(:fall_alpha_bravo)

    assert_difference('Lineup.count' => -1, 'Game.count' => -3) do
      match.destroy
    end
  end

  test 'swapping a team drops its lineup picks and keeps the other teams' do
    match = matches(:scorecard_match)
    LineupPick.create!(match: match, team: teams(:sc_home), player: players(:sc_home_player1), position: 1, seat: 1)
    LineupPick.create!(match: match, team: teams(:sc_away), player: players(:sc_away_player1), position: 1, seat: 1)

    match.update!(away_team: teams(:sc_other))

    assert_equal [teams(:sc_home).id], match.lineup_picks.pluck(:team_id)
  end

  test 'rejects a match night from a different season' do
    match = Match.new(season: seasons(:spring), match_night: match_nights(:fall_week_one),
                      home_team: teams(:alpha), away_team: teams(:bravo))

    assert_not match.valid?
    assert_includes match.errors[:match_night], "must belong to this match's season"
  end

  test 'rejects teams that are the same' do
    match = Match.new(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                      home_team: teams(:alpha), away_team: teams(:alpha))

    assert_not match.valid?
    assert_includes match.errors[:away_team], 'must be different from the home team'
  end
end
