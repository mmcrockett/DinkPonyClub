require 'test_helper'

class CourtScheduleTest < ActiveSupport::TestCase
  setup do
    @night = match_nights(:fall_upcoming)
    @match = matches(:fall_future)
    @one = match_slots(:fall_future_slot_one)
    @two = match_slots(:fall_future_slot_two)
  end

  def schedule
    CourtSchedule.new(@night)
  end

  def pick(player, position, team: teams(:alpha), seat: 1)
    LineupPick.create!(match: @match, team: team, player: player, position: position, seat: seat)
  end

  test 'rows list every time and court with the placed line' do
    rows = schedule.rows.to_h

    assert_equal 3, rows.size
    assert_equal CourtAssignment::COURTS, rows[@one].keys
    assert_equal 1, rows[@one][1].position
    assert_nil rows[@one][2]
  end

  test 'a cell carries each side players in seat order' do
    pick(players(:grace), 1, seat: 2)
    pick(players(:ada), 1, seat: 1)
    pick(players(:sam), 1, team: teams(:bravo))
    cell = schedule.rows.to_h[@one][1]

    assert_equal [players(:ada), players(:grace)], cell.home_players
    assert_equal [players(:sam)], cell.away_players
  end

  test 'unplaced lists the lines with no court yet' do
    assert_equal [2, 3, 4, 5], schedule.unplaced.map(&:last)
  end

  test 'selected names the placed line' do
    assert_equal "#{@match.id}-1", schedule.selected(@one, 1)
    assert_nil schedule.selected(@one, 2)
  end

  test 'flags a player who said no to the time' do
    SlotAvailability.create!(match_slot: @one, player: players(:grace), preference: 'thumbs_down')
    pick(players(:grace), 1)

    assert_equal([[:declined, players(:grace), @one]], schedule.conflicts.map { |c| [c.kind, c.player, c.slot] })
    assert_equal [:declined], schedule.conflict_kinds(@one, players(:grace))
  end

  test 'flags a sub placed in two lines at the same time' do
    other = Match.create!(season: @match.season, match_night: @night, home_team: teams(:bravo),
                          away_team: teams(:alpha))
    CourtAssignment.create!(match: other, match_slot: @one, position: 1, court: 2)
    sub = players(:wade)
    pick(sub, 1)
    LineupPick.create!(match: other, team: teams(:bravo), player: sub, position: 1, seat: 1)

    assert_equal([[:double_booked, sub, @one]], schedule.conflicts.map { |c| [c.kind, c.player, c.slot] })
    assert_equal [:double_booked], schedule.conflict_kinds(@one, sub)
  end

  test 'a clean schedule has no conflicts' do
    pick(players(:ada), 1)

    assert_empty schedule.conflicts
  end
end
