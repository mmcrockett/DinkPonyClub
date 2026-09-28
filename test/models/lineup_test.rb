require 'test_helper'

class LineupTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate lineups(:fall_alpha_bravo_one), :valid?
  end

  test 'position is unique within a match' do
    lineup = Lineup.new(match: matches(:fall_alpha_bravo), position: 1)

    assert_not lineup.valid?
    assert_includes lineup.errors[:position], 'has already been taken'
  end

  test 'rejects more than three games' do
    lineup = lineups(:fall_alpha_bravo_one)
    lineup.games.build(number: 1, home_score: 11, away_score: 4,
                       home_player_a: players(:ada), home_player_b: players(:grace),
                       away_player_a: players(:sam), away_player_b: players(:ben))

    assert_not lineup.valid?
    assert_includes lineup.errors[:base], 'cannot have more than 3 games'
  end

  test 'ordered scope sorts by position' do
    second = matches(:fall_alpha_bravo).lineups.create!(position: 2)

    assert_equal [lineups(:fall_alpha_bravo_one), second], matches(:fall_alpha_bravo).lineups.ordered.to_a
  end

  test 'complete? is true once it has three games' do
    assert_predicate lineups(:fall_alpha_bravo_one), :complete?
  end
end
