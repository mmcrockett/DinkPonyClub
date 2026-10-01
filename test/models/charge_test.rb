require 'test_helper'

class ChargeTest < ActiveSupport::TestCase
  test 'balance is amount minus paid' do
    assert_equal 4000, charges(:ada_league_fee).balance_cents
  end

  test 'owing covers only unpaid or partly paid charges' do
    assert_includes Charge.owing, charges(:ada_league_fee)
    assert_not_includes Charge.owing, charges(:grace_league_fee)
  end

  test 'owing_player_ids lists players with a balance in the season' do
    assert_equal [players(:ada).id], Charge.owing_player_ids(seasons(:fall))
    assert_empty Charge.owing_player_ids(seasons(:spring))
  end

  test 'a player is charged a fee at most once' do
    charge = Charge.new(roster_spot: roster_spots(:fall_alpha_ada), fee: fees(:fall_league_fee), amount_cents: 1)

    assert_not charge.valid?
  end

  test 'paid cannot exceed the amount' do
    charge = charges(:ada_league_fee)
    charge.paid_cents = charge.amount_cents + 1

    assert_not charge.valid?
  end

  test 'a new roster spot picks up the everyone fees only' do
    spot = RosterSpot.create!(season: seasons(:fall), team: teams(:bravo), player: players(:zoe))

    assert_equal [fees(:fall_league_fee)], spot.charges.map(&:fee)
  end
end
