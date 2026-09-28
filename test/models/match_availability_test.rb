require 'test_helper'

class MatchAvailabilityTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate match_availabilities(:fall_future_ada), :valid?
  end

  test 'rejects a duplicate player within a match night' do
    availability = MatchAvailability.new(match_night: match_nights(:fall_upcoming), player: players(:ada),
                                         status: 'in')

    assert_not availability.valid?
    assert_includes availability.errors[:player_id], 'has already been taken'
  end

  test 'defaults status to maybe' do
    availability = MatchAvailability.create!(match_night: match_nights(:fall_upcoming), player: players(:sam))

    assert_predicate availability, :maybe?
  end

  test 'exposes in/maybe/out predicates' do
    assert_predicate match_availabilities(:fall_future_ada), :in?
    assert_predicate match_availabilities(:fall_future_grace), :out?
  end
end
