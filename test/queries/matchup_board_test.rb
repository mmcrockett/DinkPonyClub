require 'test_helper'

class MatchupBoardTest < ActiveSupport::TestCase
  setup do
    @match = matches(:scorecard_match)
    @team = teams(:sc_home)
    @picked = players(:sc_home_player1)
    LineupPick.create!(match: @match, team: @team, player: @picked, position: 1, seat: 1)
    @board = MatchupBoard.new(@match, @team)
  end

  test 'lines are padded to three seats' do
    _position, rows = @board.lines.first

    assert_equal [@picked, nil, nil], rows.map(&:player)
  end

  test 'bench excludes picked players' do
    assert_not_includes @board.bench.map(&:player), @picked
    assert_not_empty @board.bench
  end

  test 'sub_options offers unrostered players but not out ones or rostered ones' do
    free = Player.create!(first_name: 'Free', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    out = Player.create!(first_name: 'Out', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    MatchAvailability.create!(match_night: @match.match_night, player: out, status: 'out')
    options = MatchupBoard.new(@match, @team).sub_options.map(&:player)

    assert_includes options, free
    assert_not_includes options, out
    assert_not_includes options, @picked
  end

  test 'a picked sub is flagged as a sub' do
    sub = Player.create!(first_name: 'Free', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    LineupPick.create!(match: @match, team: @team, player: sub, position: 2, seat: 1)
    row = MatchupBoard.new(@match, @team).lines.to_h.fetch(2).first

    assert row.sub
    assert_not @board.lines.to_h.fetch(1).first.sub
  end

  test 'opponent is the other team' do
    assert_equal teams(:sc_away), @board.opponent
  end
end
