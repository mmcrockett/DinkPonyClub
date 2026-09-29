require 'test_helper'

class GameTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate games(:fall_alpha_bravo_one_game_one), :valid?
  end

  test 'rejects a game that ends 11-10' do
    game = Game.new(lineup: lineups(:fall_alpha_bravo_one), number: 1, home_score: 11, away_score: 10,
                    home_player_a: players(:ada), home_player_b: players(:grace),
                    away_player_a: players(:sam), away_player_b: players(:ben))

    assert_not game.valid?
    assert_includes game.errors[:base], 'must be played to 11, win by 2'
  end

  test 'rejects a game where nobody reached 11' do
    game = Game.new(lineup: lineups(:fall_alpha_bravo_one), number: 1, home_score: 9, away_score: 5,
                    home_player_a: players(:ada), home_player_b: players(:grace),
                    away_player_a: players(:sam), away_player_b: players(:ben))

    assert_not game.valid?
    assert_includes game.errors[:base], 'must be played to 11, win by 2'
  end

  test 'accepts a game that ends 12-10' do
    game = Game.new(lineup: Lineup.new, number: 1, home_score: 12, away_score: 10,
                    home_player_a: players(:ada), home_player_b: players(:grace),
                    away_player_a: players(:sam), away_player_b: players(:ben))

    assert_predicate game, :valid?
  end

  test 'rejects a duplicate game number within a lineup' do
    game = Game.new(lineup: lineups(:fall_alpha_bravo_one), number: 1, home_score: 11, away_score: 5,
                    home_player_a: players(:ada), home_player_b: players(:grace),
                    away_player_a: players(:sam), away_player_b: players(:ben))

    assert_not game.valid?
    assert_includes game.errors[:number], 'has already been taken'
  end

  test 'rejects a repeated player' do
    game = games(:fall_alpha_bravo_one_game_one)
    game.home_player_b = game.home_player_a

    assert_not game.valid?
    assert_includes game.errors[:base], 'players must be distinct within a game'
  end

  test 'rejects a player already used in another lineup of the same match' do
    other_lineup = matches(:fall_alpha_bravo).lineups.create!(position: 2)
    game = other_lineup.games.new(number: 1, home_score: 11, away_score: 5,
                                  home_player_a: players(:ada), home_player_b: players(:grace),
                                  away_player_a: players(:sam), away_player_b: players(:ben))

    assert_not game.valid?
    assert_includes game.errors[:base], 'players can only appear in one lineup per match'
  end
end
