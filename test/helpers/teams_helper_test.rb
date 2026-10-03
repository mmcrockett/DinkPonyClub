require 'test_helper'

class TeamsHelperTest < ActionView::TestCase
  test 'team_logo renders the logo matching the team name' do
    assert_includes team_logo(Team.new(name: 'Old Balls, New Flicks')), 'old-balls-new-flicks'
  end

  test 'team_logo is nil for a team without a logo' do
    assert_nil team_logo(Team.new(name: 'Test Team Alpha'))
  end
end
