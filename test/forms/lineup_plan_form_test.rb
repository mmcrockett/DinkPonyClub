require 'test_helper'

class LineupPlanFormTest < ActiveSupport::TestCase
  setup do
    @match = matches(:scorecard_match)
    @team = teams(:sc_home)
  end

  test 'saves picks in line and seat order' do
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => ids(1, 2, 3), 2 => ids(4, 5) })

    assert_difference('LineupPick.count', 5) { assert form.save }
    assert_equal ids(1, 2, 3), LineupPlanForm.from_match(@match, @team).lines[1]
  end

  test 'a four-line night offers four lines' do
    @match.match_night.update!(lines_count: 4)
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 5 => ids(1, 2) })

    assert_equal [1, 2, 3, 4], form.lines.keys
  end

  test 'save replaces only this teams picks' do
    LineupPick.create!(match: @match, team: teams(:sc_away), player: players(:sc_away_player1), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: @team, player: players(:sc_home_player1), position: 1, seat: 1)

    assert LineupPlanForm.new(match: @match, team: @team, lines: { 3 => ids(2, 3) }).save
    assert_equal 1, @match.lineup_picks.where(team: teams(:sc_away)).count
    assert_equal [3], @match.lineup_picks.where(team: @team).pluck(:position).uniq
  end

  test 'a line with a single player is invalid' do
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => ids(1) })

    assert_not form.save
    assert_includes form.errors.full_messages.to_sentence, 'Line 1'
  end

  test 'a player cannot appear twice' do
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => ids(1, 2), 2 => ids(2, 3) })

    assert_not form.valid?
  end

  test 'rejects a player from another roster' do
    other = players(:sc_away_player1).id.to_s
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => [ids(1).first, other] })

    assert_not form.valid?
  end

  test 'an active player with no roster spot this season can be picked as a sub' do
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => [players(:ada).id.to_s, ids(1).first] })

    assert form.save
    assert_equal [players(:ada)], form.subs
  end

  test 'an inactive player cannot be picked as a sub' do
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => [players(:wade).id.to_s, ids(1).first] })

    assert_not form.valid?
  end

  test 'a sub picked by the opponent is no longer eligible' do
    LineupPick.create!(match: @match, team: teams(:sc_away), player: players(:ada), position: 1, seat: 1)
    form = LineupPlanForm.new(match: @match, team: @team, lines: { 1 => [players(:ada).id.to_s, ids(1).first] })

    assert_not_includes form.eligible_subs, players(:ada)
    assert_not form.save
  end

  test 'blank lines are allowed' do
    assert LineupPlanForm.new(match: @match, team: @team, lines: {}).save
  end

  private

  def ids(*numbers)
    numbers.map { |n| players(:"sc_home_player#{n}").id.to_s }
  end
end
