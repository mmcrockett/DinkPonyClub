require 'test_helper'

class LineupTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate lineups(:fall_alpha_bravo_one), :valid?
  end

  test 'worked example splits match points 2-1' do
    lineup = lineups(:fall_alpha_bravo_one)

    assert_equal 2, lineup.match_points_for(:home)
    assert_equal 1, lineup.match_points_for(:away)
  end

  test 'a sweep earns the bonus point' do
    lineup = lineups(:fall_alpha_bravo_one)
    lineup.games.destroy_all
    lineup.games.create!(number: 1, home_score: 11, away_score: 4)
    lineup.games.create!(number: 2, home_score: 11, away_score: 6)
    lineup.games.create!(number: 3, home_score: 11, away_score: 8)

    assert_equal 4, lineup.reload.match_points_for(:home)
    assert_equal 0, lineup.match_points_for(:away)
  end

  test 'rejects a repeated player' do
    lineup = lineups(:fall_alpha_bravo_one)
    lineup.home_player_two = lineup.home_player_one

    assert_not lineup.valid?
    assert_includes lineup.errors[:base], 'players must be distinct within a lineup'
  end

  test 'rejects a player not on that team roster for the season' do
    lineup = lineups(:fall_alpha_bravo_one)
    lineup.away_player_one = players(:grace)

    assert_not lineup.valid?
    assert_includes lineup.errors[:base], 'away players must be on the away team roster for this season'
  end

  test 'rejects a player already used in another lineup of the same match' do
    lineup = lineups(:fall_alpha_bravo_one).match.lineups.new(
      position: 2,
      home_player_one: players(:ada),
      home_player_two: players(:grace),
      away_player_one: players(:sam),
      away_player_two: players(:ben)
    )

    assert_not lineup.valid?
    assert_includes lineup.errors[:base], 'players can only appear in one lineup per match'
  end
end
