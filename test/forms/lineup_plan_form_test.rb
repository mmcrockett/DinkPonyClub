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

  test 'blank lines are allowed' do
    assert LineupPlanForm.new(match: @match, team: @team, lines: {}).save
  end

  private

  def ids(*numbers)
    numbers.map { |n| players(:"sc_home_player#{n}").id.to_s }
  end
end
