require 'test_helper'

class RosterSpotTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate roster_spots(:fall_alpha_ada), :valid?
  end

  test 'rejects the same player twice in one season' do
    spot = RosterSpot.new(season: seasons(:fall), team: teams(:bravo), player: players(:ada))

    assert_not spot.valid?
    assert_includes spot.errors[:player_id], 'has already been taken'
  end

  test 'allows the same player on the same team in a different season' do
    spot = RosterSpot.new(season: seasons(:spring), team: teams(:alpha), player: players(:grace))

    assert_predicate spot, :valid?
  end

  test 'captain defaults to false' do
    assert_equal false, RosterSpot.new.captain
  end

  test 'captains scope returns only captains' do
    assert_includes RosterSpot.captains, roster_spots(:fall_alpha_ada)
    assert_not_includes RosterSpot.captains, roster_spots(:fall_alpha_grace)
  end
end
