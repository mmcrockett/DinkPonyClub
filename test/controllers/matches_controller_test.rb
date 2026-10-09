require 'test_helper'

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match = matches(:scorecard_match)
    travel_to @match.played_on.in_time_zone.change(hour: 20)
  end

  test 'show redirects to root when signed out' do
    get match_path(@match)

    assert_redirected_to root_path
  end

  test 'edit redirects to root when signed out' do
    get edit_match_path(@match)

    assert_redirected_to root_path
  end

  test 'show renders for any signed-in player and hides the edit link for a non-captain' do
    sign_in_as players(:sc_home_player1)

    get match_path(@match)

    assert_response :success
    assert_select "a[href='#{edit_match_path(@match)}']", count: 0
  end

  test 'show shows the edit link for the home captain' do
    sign_in_as players(:sc_home_captain)

    get match_path(@match)

    assert_response :success
    assert_select "a[href='#{edit_match_path(@match)}']"
  end

  test 'edit redirects a non-captain to the match' do
    sign_in_as players(:sc_home_player1)

    get edit_match_path(@match)

    assert_redirected_to match_path(@match)
  end

  test 'edit renders for a captain of an uninvolved team in the same season' do
    sign_in_as players(:sc_other_captain)

    get edit_match_path(@match)

    assert_response :success
  end

  test 'edit redirects a captain from a different season' do
    sign_in_as players(:ada)

    get edit_match_path(@match)

    assert_redirected_to match_path(@match)
  end

  test 'edit renders for the home captain' do
    sign_in_as players(:sc_home_captain)

    get edit_match_path(@match)

    assert_response :success
    assert_select 'button[data-action="scorecard#setLineup"] svg'
  end

  test 'edit renders for the away captain' do
    sign_in_as players(:sc_away_captain)

    get edit_match_path(@match)

    assert_response :success
  end

  test 'edit renders for an admin' do
    sign_in_as players(:zoe)

    get edit_match_path(@match)

    assert_response :success
  end

  test 'update saves a valid scorecard for the home captain' do
    sign_in_as players(:sc_home_captain)

    assert_difference('Lineup.count', 5) do
      patch match_path(@match), params: { scorecard: { lines: valid_lines } }
    end

    assert_redirected_to match_path(@match)
  end

  test 'update rejects a captain from a different season' do
    sign_in_as players(:ada)

    assert_no_difference('Lineup.count') do
      patch match_path(@match), params: { scorecard: { lines: valid_lines } }
    end

    assert_redirected_to match_path(@match)
  end

  test 'update renders the edit form again on an invalid scorecard' do
    sign_in_as players(:sc_home_captain)

    lines = valid_lines
    lines['1'][:home_player_ids] = [players(:sc_home_captain).id.to_s]

    assert_no_difference('Lineup.count') do
      patch match_path(@match), params: { scorecard: { lines: lines } }
    end

    assert_response :unprocessable_entity
  end

  test 'edit redirects a captain once results are locked' do
    sign_in_as players(:sc_home_captain)

    travel_to @match.match_night.results_locked_at + 1.minute do
      get edit_match_path(@match)
    end

    assert_redirected_to match_path(@match)
    assert_equal I18n.t('matches.locked'), flash[:alert]
  end

  test 'update is rejected for a captain once results are locked' do
    sign_in_as players(:sc_home_captain)

    travel_to @match.match_night.results_locked_at + 1.minute do
      patch match_path(@match), params: { scorecard: { lines: valid_lines } }
    end

    assert_redirected_to match_path(@match)
    assert_equal I18n.t('matches.locked'), flash[:alert]
  end

  test 'edit still renders for a captain just before the lock' do
    sign_in_as players(:sc_home_captain)

    travel_to @match.match_night.results_locked_at - 1.minute do
      get edit_match_path(@match)
    end

    assert_response :success
  end

  test 'edit still renders for an admin once results are locked' do
    sign_in_as players(:zoe)

    travel_to @match.match_night.results_locked_at + 1.day do
      get edit_match_path(@match)
    end

    assert_response :success
  end

  test 'show hides the edit link from a captain once results are locked' do
    sign_in_as players(:sc_home_captain)

    travel_to @match.match_night.results_locked_at + 1.minute do
      get match_path(@match)
    end

    assert_select "a[href='#{edit_match_path(@match)}']", count: 0
  end

  test 'edit lists a planned sub in the dropdowns and keeps them selected' do
    sign_in_as players(:sc_home_captain)
    LineupPick.create!(match: @match, team: teams(:sc_home), player: players(:ada), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: teams(:sc_home), player: players(:sc_home_player1), position: 1, seat: 2)

    get edit_match_path(@match)

    assert_select 'option[selected]', text: players(:ada).full_name
  end

  test 'edit renders a block per line with a score row for each of the three games' do
    sign_in_as players(:sc_home_captain)

    get edit_match_path(@match)

    assert_select 'section', count: @match.line_positions.size
    assert_select "[data-scorecard-target='row']", count: 3 * @match.line_positions.size
  end

  test 'edit shows the lineup editor and hides scores when the lineup is incomplete' do
    sign_in_as players(:sc_home_captain)

    get edit_match_path(@match)

    assert_select "[data-scorecard-target='editor']:not([hidden])"
    assert_select "[data-scorecard-target='scores'][hidden]"
  end

  test 'edit shows the lineup summary and scores when every line has players' do
    sign_in_as players(:sc_home_captain)
    patch match_path(@match), params: { scorecard: { lines: valid_lines } }

    get edit_match_path(@match)

    assert_select "[data-scorecard-target='summary']:not([hidden])"
    assert_select "[data-scorecard-target='editor'][hidden]"
    assert_select "[data-scorecard-target='scores']:not([hidden])"
  end

  test 'a score error re-renders with the scores still visible' do
    sign_in_as players(:sc_home_captain)
    lines = valid_lines
    lines['1'][:away_score1] = '11'

    patch match_path(@match), params: { scorecard: { lines: lines } }

    assert_response :unprocessable_entity
    assert_select "[data-scorecard-target='scores']:not([hidden])"
    assert_select 'li', text: /cannot end in a tie/
  end

  test 'json update saves and returns a fresh fingerprint' do
    sign_in_as players(:sc_home_captain)

    patch match_path(@match, format: :json), params: { scorecard: { lines: valid_lines } }

    assert_response :success
    assert_equal ScorecardForm.from_match(@match.reload).fingerprint, response.parsed_body['fingerprint']
  end

  test 'json update returns errors for a tie' do
    sign_in_as players(:sc_home_captain)
    lines = valid_lines
    lines['1'][:away_score1] = '11'

    patch match_path(@match, format: :json), params: { scorecard: { lines: lines } }

    assert_response :unprocessable_entity
    assert_match 'tie', response.parsed_body['errors'].to_sentence
  end

  test 'json update with a stale fingerprint conflicts and changes nothing' do
    sign_in_as players(:sc_home_captain)

    assert_no_difference('Lineup.count') do
      patch match_path(@match, format: :json), params: { fingerprint: 'stale', scorecard: { lines: valid_lines } }
    end

    assert_response :conflict
  end

  test 'html update with a stale fingerprint redirects to the saved data and changes nothing' do
    sign_in_as players(:sc_home_captain)

    assert_no_difference('Lineup.count') do
      patch match_path(@match), params: { fingerprint: 'stale', scorecard: { lines: valid_lines } }
    end

    assert_redirected_to edit_match_path(@match)
    assert_equal I18n.t('matches.stale'), flash[:alert]
  end

  test 'json update is forbidden for a captain once results are locked' do
    sign_in_as players(:sc_home_captain)

    travel_to @match.match_night.results_locked_at + 1.minute do
      patch match_path(@match, format: :json), params: { scorecard: { lines: valid_lines } }
    end

    assert_response :forbidden
  end

  private

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: player.google_uid)
    post '/auth/google_oauth2'
    follow_redirect!
  end

  def valid_lines
    {
      '1' => two_player_line(:sc_home_captain, :sc_home_player1, :sc_away_captain, :sc_away_player1),
      '2' => two_player_line(:sc_home_player2, :sc_home_player3, :sc_away_player2, :sc_away_player3),
      '3' => two_player_line(:sc_home_player4, :sc_home_player5, :sc_away_player4, :sc_away_player5),
      '4' => two_player_line(:sc_home_player6, :sc_home_player7, :sc_away_player6, :sc_away_player7),
      '5' => two_player_line(:sc_home_player8, :sc_home_player9, :sc_away_player8, :sc_away_player9)
    }
  end

  def two_player_line(home_a, home_b, away_a, away_b)
    {
      home_player_ids: [players(home_a).id.to_s, players(home_b).id.to_s],
      away_player_ids: [players(away_a).id.to_s, players(away_b).id.to_s],
      home_score1: '11', away_score1: '4',
      home_score2: '11', away_score2: '6',
      home_score3: '11', away_score3: '8'
    }
  end
end
