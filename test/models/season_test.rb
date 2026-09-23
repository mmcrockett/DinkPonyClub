require 'test_helper'

class SeasonTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate seasons(:fall), :valid?
  end

  test 'requires a name' do
    season = Season.new(starts_on: Date.new(2026, 9, 1))

    assert_not season.valid?
    assert_includes season.errors[:name], "can't be blank"
  end

  test 'requires a unique name' do
    season = Season.new(name: seasons(:fall).name)

    assert_not season.valid?
    assert_includes season.errors[:name], 'has already been taken'
  end

  test 'reaches players through roster spots and teams' do
    season = seasons(:fall)

    assert_includes season.players, players(:ada)
    assert_includes season.teams, teams(:alpha)
  end

  test 'destroying a season destroys its roster spots' do
    assert_difference('RosterSpot.count', -4) do
      seasons(:fall).destroy
    end
  end

  test 'standings orders teams by points then point differential' do
    standings = seasons(:fall).standings

    assert_equal [teams(:alpha), teams(:bravo)], standings.map(&:team)
    assert_equal [2, 1], standings.map(&:points)
  end
end
