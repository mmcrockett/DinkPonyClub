require 'application_system_test_case'

class LineupSubsTest < ApplicationSystemTestCase
  test 'captain adds a sub, places them in a line, and sees them after saving' do
    match = matches(:scorecard_match)
    path = edit_match_team_lineup_path(match, teams(:sc_home))
    sign_in_as players(:sc_home_captain), return_to: path
    sub = players(:ada).full_name

    click_on '+ Sub'
    find("select[aria-label='Choose a sub']").select(sub)

    find("select[aria-label='Line 1 player 1']").select(sub)
    find("select[aria-label='Line 1 player 2']").select(players(:sc_home_player1).full_name)
    click_on 'Save lineup'

    assert_text 'Lineup saved.'
    assert_selector "select[aria-label='Line 1 player 1'] option:checked", text: sub
  end
end
