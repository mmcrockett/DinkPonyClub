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

  test 'sub_options offers unrostered players, out ones last, but not rostered ones' do
    free = Player.create!(first_name: 'Free', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    out = Player.create!(first_name: 'Out', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    MatchAvailability.create!(match_night: @match.match_night, player: out, status: 'out')
    options = MatchupBoard.new(@match, @team).sub_options.map(&:player)

    assert_includes options, free
    assert_equal out, options.last
    assert_not_includes options, @picked
  end

  test 'a picked sub is flagged as a sub' do
    sub = Player.create!(first_name: 'Free', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    LineupPick.create!(match: @match, team: @team, player: sub, position: 2, seat: 1)
    row = MatchupBoard.new(@match, @team).lines.to_h.fetch(2).first

    assert row.sub
    assert_not @board.lines.to_h.fetch(1).first.sub
  end

  test 'rows carry availability and out players sink to the bottom of the bench' do
    bench_first = @board.bench.first.player
    MatchAvailability.create!(match_night: @match.match_night, player: bench_first, status: 'out')
    board = MatchupBoard.new(@match, @team)

    assert_equal 'out', board.bench.last.status
    assert_equal bench_first, board.bench.last.player
  end

  test 'team summaries cover every planned player on each side' do
    away = teams(:sc_away)
    LineupPick.create!(match: @match, team: away, player: players(:sc_away_player1), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: away, player: players(:sc_away_player2), position: 1, seat: 2)
    board = MatchupBoard.new(@match, @team)

    assert_equal [@picked.full_name], board.team_summary.names
    assert_equal 2, board.opponent_team_summary.names.size
  end

  test 'a side with no picks has an empty summary' do
    summary = @board.opponent_team_summary

    assert_empty summary.names
    assert_nil summary.pupr
  end

  test 'opponent is the other team' do
    assert_equal teams(:sc_away), @board.opponent
  end
end
