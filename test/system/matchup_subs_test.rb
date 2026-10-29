require 'application_system_test_case'

class MatchupSubsTest < ApplicationSystemTestCase
  test 'a captain marks a sub out and the sub stays listed, dimmed' do
    match = matches(:scorecard_match)
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    path = season_matchup_path(match.season, team_id: match.home_team_id, match_id: match.id)
    sign_in_as players(:sc_home_captain), return_to: path

    click_button '+ Sub'
    within('dialog[open]') do
      within(:xpath, ".//li[contains(., 'Dana Sub')]") { click_button 'Out' }

      assert_selector 'li.opacity-60', text: 'Dana Sub'
      assert_selector 'li:last-child button', text: /undo/i
    end
    assert_equal 'out', match.match_night.match_availabilities.find_by!(player: sub).status
  end
end
