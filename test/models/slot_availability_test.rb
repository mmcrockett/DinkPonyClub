require 'test_helper'

class SlotAvailabilityTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate slot_availabilities(:fall_future_slot_one_ada), :valid?
  end

  test 'rejects a duplicate player within a slot' do
    availability = SlotAvailability.new(match_slot: match_slots(:fall_future_slot_one), player: players(:ada),
                                        preference: 'meh')

    assert_not availability.valid?
    assert_includes availability.errors[:player_id], 'has already been taken'
  end

  test 'defaults preference to meh' do
    availability = SlotAvailability.create!(match_slot: match_slots(:fall_future_slot_three), player: players(:sam))

    assert_predicate availability, :meh?
  end
end
