require 'test_helper'

class MatchAvailabilityTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate match_availabilities(:fall_future_ada), :valid?
  end

  test 'rejects a duplicate player within a match' do
    availability = MatchAvailability.new(match: matches(:fall_future), player: players(:ada), playing: true)

    assert_not availability.valid?
    assert_includes availability.errors[:player_id], 'has already been taken'
  end

  test 'defaults playing to true' do
    availability = MatchAvailability.create!(match: matches(:fall_future), player: players(:sam))

    assert_predicate availability, :playing?
  end
end
