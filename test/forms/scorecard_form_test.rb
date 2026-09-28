require 'test_helper'

class ScorecardFormTest < ActiveSupport::TestCase
  setup do
    @match = matches(:scorecard_match)
  end

  test 'saves a full valid scorecard across five lines' do
    form = ScorecardForm.new(match: @match, lines: valid_lines)

    assert_predicate form, :valid?
    assert_difference('Lineup.count', 5) do
      assert_difference('Game.count', 15) do
        assert form.save
      end
    end

    result = MatchResult.new(@match.reload)

    assert_predicate result, :complete?
  end

  test 'rotates a three-player line through P1/P2, P1/P3, P2/P3' do
    home_ids = player_ids(:sc_home_player10, :sc_home_player11, :sc_home_player12)
    away_ids = player_ids(:sc_away_player10, :sc_away_player11, :sc_away_player12)
    lines = valid_lines
    lines['2'] = lines['2'].merge(home_player_ids: home_ids, away_player_ids: away_ids)
    form = ScorecardForm.new(match: @match, lines: lines)

    assert form.save

    games = @match.lineups.find_by(position: 2).games.order(:number)

    assert_equal [home_ids[0], home_ids[1]], [games[0].home_player_a_id.to_s, games[0].home_player_b_id.to_s]
    assert_equal [home_ids[0], home_ids[2]], [games[1].home_player_a_id.to_s, games[1].home_player_b_id.to_s]
    assert_equal [home_ids[1], home_ids[2]], [games[2].home_player_a_id.to_s, games[2].home_player_b_id.to_s]
  end

  test 'plays a two-player line on the same pair for all three games' do
    form = ScorecardForm.new(match: @match, lines: valid_lines)

    assert form.save

    games = @match.lineups.find_by(position: 1).games.order(:number)
    home_ids = [players(:sc_home_captain).id, players(:sc_home_player1).id]

    games.each do |game|
      assert_equal home_ids, [game.home_player_a_id, game.home_player_b_id]
    end
  end

  test 'rejects a line with fewer than two players on a side' do
    lines = valid_lines
    lines['1'][:home_player_ids] = [players(:sc_home_captain).id.to_s]
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1: home side needs at least two players'
  end

  test 'rejects a player appearing on both sides of a line' do
    lines = valid_lines
    lines['1'][:away_player_ids] = [players(:sc_home_captain).id.to_s, players(:sc_away_player1).id.to_s]
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1: a player cannot play both sides of a line'
  end

  test 'rejects a player who appears on two lines' do
    lines = valid_lines
    lines['2'][:home_player_ids] = [players(:sc_home_captain).id.to_s, players(:sc_home_player5).id.to_s]
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1 and Line 2: a player cannot appear on two lines'
  end

  test 'rejects a player who is not on that side roster for the season' do
    lines = valid_lines
    lines['1'][:home_player_ids] = [players(:ada).id.to_s, players(:sc_home_player1).id.to_s]
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1: home players must be on the home team roster for this season'
  end

  test 'rejects a tied score' do
    lines = valid_lines
    lines['1'][:home_score1] = '10'
    lines['1'][:away_score1] = '10'
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1: game 1 cannot end in a tie'
  end

  test 'rejects a game with only one score present' do
    lines = valid_lines
    lines['1'][:away_score1] = ''
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_not form.valid?
    assert_includes form.errors[:base], 'Line 1: game 1 needs both scores'
  end

  test 'rejects a score that does not satisfy the 11 win-by-2 rule via the underlying Game validation' do
    lines = valid_lines
    lines['1'][:home_score1] = '11'
    lines['1'][:away_score1] = '10'
    form = ScorecardForm.new(match: @match, lines: lines)

    assert_predicate form, :valid?
    assert_not form.save
    assert(form.errors[:base].any? { |message| message.include?('win by 2') })
  end

  test 'leaves an existing lineup untouched when the submission is invalid' do
    ScorecardForm.new(match: @match, lines: valid_lines).save
    invalid_lines = valid_lines
    invalid_lines['1'][:home_player_ids] = [players(:sc_home_captain).id.to_s]

    assert_no_difference('Lineup.count') do
      assert_no_difference('Game.count') do
        assert_not ScorecardForm.new(match: @match, lines: invalid_lines).save
      end
    end
  end

  test 'allows a game with both scores blank, leaving the lineup incomplete' do
    lines = valid_lines
    lines['1'][:home_score3] = ''
    lines['1'][:away_score3] = ''
    form = ScorecardForm.new(match: @match, lines: lines)

    assert form.save

    lineup = @match.reload.lineups.find_by(position: 1)

    assert_equal 2, lineup.games.count
    assert_not lineup.complete?
  end

  private

  def player_ids(*names)
    names.map { |name| players(name).id.to_s }
  end

  def valid_lines
    {
      '1' => two_player_line(:sc_home_captain, :sc_home_player1, :sc_away_captain, :sc_away_player1,
                             scores: [%w[11 4], %w[11 6], %w[11 8]]),
      '2' => two_player_line(:sc_home_player2, :sc_home_player3, :sc_away_player2, :sc_away_player3,
                             scores: [%w[9 11], %w[11 9], %w[11 7]]),
      '3' => two_player_line(:sc_home_player4, :sc_home_player5, :sc_away_player4, :sc_away_player5,
                             scores: [%w[11 5], %w[7 11], %w[11 9]]),
      '4' => two_player_line(:sc_home_player6, :sc_home_player7, :sc_away_player6, :sc_away_player7,
                             scores: [%w[11 6], %w[11 7], %w[11 8]]),
      '5' => two_player_line(:sc_home_player8, :sc_home_player9, :sc_away_player8, :sc_away_player9,
                             scores: [%w[11 3], %w[11 4], %w[9 11]])
    }
  end

  def two_player_line(home_a, home_b, away_a, away_b, scores:)
    attrs = { home_player_ids: player_ids(home_a, home_b), away_player_ids: player_ids(away_a, away_b) }
    scores.each_with_index do |(home_score, away_score), index|
      attrs[:"home_score#{index + 1}"] = home_score
      attrs[:"away_score#{index + 1}"] = away_score
    end
    attrs
  end
end
