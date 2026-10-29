require 'test_helper'

class CourtAssignmentTest < ActiveSupport::TestCase
  setup do
    @match = matches(:fall_future)
    @slot = match_slots(:fall_future_slot_two)
  end

  test 'valid fixture' do
    assert_predicate court_assignments(:fall_future_line_one), :valid?
  end

  test 'court must be one of the club courts' do
    assignment = CourtAssignment.new(match: @match, match_slot: @slot, position: 2, court: 5)

    assert_not assignment.valid?
    assert_includes assignment.errors[:court], 'is not included in the list'
  end

  test 'position must be a line of the night' do
    assignment = CourtAssignment.new(match: @match, match_slot: @slot, position: 9, court: 1)

    assert_not assignment.valid?
    assert_includes assignment.errors[:position], 'is not included in the list'
  end

  test 'a line is placed once' do
    assignment = CourtAssignment.new(match: @match, match_slot: @slot, position: 1, court: 2)

    assert_not assignment.valid?
    assert_includes assignment.errors[:position], 'has already been taken'
  end

  test 'a court holds one line per time' do
    assignment = CourtAssignment.new(match: @match, match_slot: match_slots(:fall_future_slot_one), position: 2,
                                     court: 1)

    assert_not assignment.valid?
    assert_includes assignment.errors[:court], 'has already been taken'
  end

  test 'the time must belong to the match night' do
    other = MatchSlot.create!(match_night: match_nights(:fall_canceled), position: 1, starts_at: Time.current)
    assignment = CourtAssignment.new(match: @match, match_slot: other, position: 2, court: 1)

    assert_not assignment.valid?
    assert_includes assignment.errors[:match_slot], "must belong to this match's night"
  end
end
