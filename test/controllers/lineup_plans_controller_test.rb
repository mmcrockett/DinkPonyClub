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

  test 'invalid lineup re-renders with errors' do
    sign_in_as players(:sc_home_captain)

    lone = [players(:sc_home_player1).id]
    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => lone } } }

    assert_response :unprocessable_content
  end

  test 'scorecard edit is prefilled from the planned lineup' do
    LineupPick.create!(match: @match, team: @home, player: players(:sc_home_player1), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: @home, player: players(:sc_home_player2), position: 1, seat: 2)

    form = ScorecardForm.from_match(@match)

    expected = [players(:sc_home_player1).id.to_s, players(:sc_home_player2).id.to_s]

    assert_equal expected, form.lines.first.home_player_ids
  end

  private

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: player.google_uid)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
