require 'test_helper'

class LineupPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match = matches(:scorecard_match)
    @home = teams(:sc_home)
  end

  test 'edit redirects to root when signed out' do
    get edit_match_team_lineup_path(@match, @home)

    assert_redirected_to root_path
  end

  test 'home captain can edit and save their lineup' do
    sign_in_as players(:sc_home_captain)

    get edit_match_team_lineup_path(@match, @home)

    assert_response :success

    picked = [players(:sc_home_player1).id, players(:sc_home_player2).id, '']

    assert_difference('LineupPick.count', 2) do
      patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => picked } } }
    end
    assert_redirected_to edit_match_team_lineup_path(@match, @home)
  end

  test 'away captain cannot set the home lineup' do
    sign_in_as players(:sc_away_captain)

    get edit_match_team_lineup_path(@match, @home)

    assert_redirected_to match_path(@match)
  end

  test 'a captain of an unrelated team is rejected' do
    sign_in_as players(:sc_other_captain)

    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: {} } }

    assert_redirected_to match_path(@match)
  end

  test 'a team not in the match is not found' do
    sign_in_as players(:sc_home_captain)

    get edit_match_team_lineup_path(@match, teams(:sc_other))

    assert_response :not_found
  end

  test 'redirects when the match already has scorecard lineups' do
    sign_in_as players(:sc_home_captain)
    @match.lineups.create!(position: 1)

    get edit_match_team_lineup_path(@match, @home)

    assert_redirected_to match_path(@match)
  end

  test 'admin can edit a lineup for either team' do
    sign_in_as players(:zoe)

    get edit_match_team_lineup_path(@match, @home)

    assert_response :success
  end

  test 'redirects when the night is canceled' do
    sign_in_as players(:sc_home_captain)
    @match.match_night.update!(canceled: true)

    get edit_match_team_lineup_path(@match, @home)

    assert_redirected_to match_path(@match)
  end

  test 'schedule shows a captain only their own set-lineup link' do
    sign_in_as players(:sc_home_captain)

    get season_match_nights_path(@match.season)

    assert_select "a[href='#{edit_match_team_lineup_path(@match, @home)}']"
    assert_select "a[href='#{edit_match_team_lineup_path(@match, teams(:sc_away))}']", count: 0
  end

  test 'schedule shows an admin both set-lineup links' do
    sign_in_as players(:zoe)

    get season_match_nights_path(@match.season)

    assert_select "a[href='#{edit_match_team_lineup_path(@match, @home)}']"
    assert_select "a[href='#{edit_match_team_lineup_path(@match, teams(:sc_away))}']"
  end

  test 'schedule shows a plain player no set-lineup links' do
    sign_in_as players(:sc_home_player1)

    get season_match_nights_path(@match.season)

    assert_select "a[href*='/lineup/edit']", count: 0
  end

  test 'match page hides set-lineup links once results are entered' do
    sign_in_as players(:zoe)
    @match.lineups.create!(position: 1)

    get match_path(@match)

    assert_select "a[href*='/lineup/edit']", count: 0
  end

  test 'invalid lineup re-renders with errors' do
    sign_in_as players(:sc_home_captain)

    lone = [players(:sc_home_player1).id]
    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => lone } } }

    assert_response :unprocessable_content
  end

  private

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: player.google_uid)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
