require 'test_helper'

class FeeTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate fees(:fall_league_fee), :valid?
  end

  test 'name is unique within a season' do
    fee = Fee.new(season: seasons(:fall), name: 'Hat', amount: '5')

    assert_not fee.valid?
    assert_includes fee.errors[:name], 'has already been taken'
  end

  test 'amount is parsed from dollars' do
    assert_equal 1250, Fee.new(amount: '$12.50').amount_cents
  end

  test 'rejects a non-numeric or zero amount' do
    assert_not Fee.new(season: seasons(:fall), name: 'Food', amount: 'lots').valid?
    assert_not Fee.new(season: seasons(:fall), name: 'Food', amount: '0').valid?
  end

  test 'an everyone fee charges every rostered player' do
    fee = seasons(:fall).fees.create!(name: 'Food', amount: '10', applies_to_all: true)

    assert_equal seasons(:fall).roster_spots.count, fee.charges.count
  end

  test 'an opt-in fee charges nobody' do
    fee = seasons(:fall).fees.create!(name: 'Shirt', amount: '25')

    assert_empty fee.charges
  end
end
