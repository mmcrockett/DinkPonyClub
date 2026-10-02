require 'test_helper'

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end

  test 'redirects to root when signed out' do
    delete sign_out_path

    get season_teams_path(seasons(:fall))

    assert_redirected_to root_path
  end

  test 'index lists the season teams with their record' do
    get season_teams_path(seasons(:fall))

    assert_response :success
    assert_select "li##{dom_id(teams(:alpha))} a[href='#{season_team_path(seasons(:fall), teams(:alpha))}']",
                  text: teams(:alpha).name
    assert_select "li##{dom_id(teams(:alpha))}", text: /1-0-0/
    assert_select "li##{dom_id(teams(:bravo))}", text: /0-1-0/
  end

  test 'show has the record, roster with captain and player links' do
    get season_team_path(seasons(:fall), teams(:alpha))

    assert_response :success
    assert_select 'h1', text: teams(:alpha).name
    assert_select '.roster li', count: 2
    assert_select '.roster .captain-chip', count: 1
    assert_select ".roster a[href='#{season_player_path(seasons(:fall), players(:ada))}']"
  end

  test 'show lists played and upcoming matches from the team perspective' do
    get season_team_path(seasons(:fall), teams(:bravo))

    assert_select "li##{dom_id(matches(:fall_alpha_bravo), :team)}", text: /1 - 2/ do
      assert_select 'a', text: teams(:alpha).name
      assert_select 'a[href=?]', match_path(matches(:fall_alpha_bravo)), text: 'Scorecard'
    end
    assert_select "li##{dom_id(matches(:fall_future), :team)}", text: /Scheduled/
  end

  test 'show says so when the team is not part of the season' do
    get season_team_path(seasons(:scorecard), teams(:alpha))

    assert_response :success
    assert_select 'p', text: "This team isn't part of this season."
  end

  test 'show is a 404 for an unknown team' do
    get season_team_path(seasons(:fall), 0)

    assert_response :not_found
  end

  test 'standings and schedule link team names to the team page' do
    get season_standings_path(seasons(:fall))

    assert_select "tr##{dom_id(teams(:alpha), :standings)} a[href='#{season_team_path(seasons(:fall), teams(:alpha))}']"

    get season_match_nights_path(seasons(:fall))

    assert_select "a[href='#{season_team_path(seasons(:fall).id, teams(:bravo))}']", minimum: 1
  end
end
