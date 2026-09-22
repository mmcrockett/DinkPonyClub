require 'test_helper'

class TeamTest < ActiveSupport::TestCase
  test 'valid fixture' do
    assert_predicate teams(:alpha), :valid?
  end

  test 'requires a unique name' do
    team = Team.new(name: teams(:alpha).name)

    assert_not team.valid?
    assert_includes team.errors[:name], 'has already been taken'
  end

  test 'persists across seasons' do
    assert_includes teams(:alpha).seasons, seasons(:fall)
    assert_includes teams(:alpha).seasons, seasons(:spring)
  end

  test 'roster_for returns only that season players, sorted by name' do
    roster = teams(:alpha).roster_for(seasons(:fall))

    assert_equal [players(:ada), players(:grace)], roster.to_a
  end

  test 'destroying a team destroys its roster spots' do
    assert_difference('RosterSpot.count', -1) do
      teams(:bravo).destroy
    end
  end
end
