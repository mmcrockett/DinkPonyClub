require 'test_helper'

class MatchSlotTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate match_slots(:fall_future_slot_one), :valid?
  end

  test 'requires a starts_at' do
    slot = MatchSlot.new(match: matches(:fall_future), position: 4)

    assert_not slot.valid?
    assert_includes slot.errors[:starts_at], "can't be blank"
  end

  test 'position is unique within a match' do
    slot = MatchSlot.new(match: matches(:fall_future), position: 1, starts_at: Time.current)

    assert_not slot.valid?
    assert_includes slot.errors[:position], 'has already been taken'
  end

  test 'ordered scope sorts by starts_at' do
    assert_equal match_slots(:fall_future_slot_one, :fall_future_slot_two, :fall_future_slot_three),
                 matches(:fall_future).match_slots.ordered.to_a
  end
end
