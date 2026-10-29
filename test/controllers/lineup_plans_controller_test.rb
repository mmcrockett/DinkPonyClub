require 'test_helper'

class LineupPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @match = matches(:scorecard_match)
    @home = teams(:sc_home)
    @matchup_path = season_matchup_path(@match.season_id, team_id: @home.id, match_id: @match.id)
  end

  test 'update redirects to root when signed out' do
    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: {} } }

    assert_redirected_to root_path
  end

  test 'home captain can save their lineup and lands back on the matchup page' do
    sign_in_as players(:sc_home_captain)
    picked = [players(:sc_home_player1).id, players(:sc_home_player2).id, '']

    assert_difference('LineupPick.count', 2) do
      patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => picked } } }
    end
    assert_redirected_to @matchup_path
  end

  test 'a one-player line can be saved' do
    sign_in_as players(:sc_home_captain)
    lone = [players(:sc_home_player1).id]

    assert_difference('LineupPick.count', 1) do
      patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => lone } } }
    end
  end

  test 'save returns to a same-site return_to and ignores off-site ones' do
    sign_in_as players(:sc_home_captain)
    picked = [players(:sc_home_player1).id, players(:sc_home_player2).id]

    patch match_team_lineup_path(@match, @home), params: { return_to: '/matchup', lineup: { lines: { '1' => picked } } }

    assert_redirected_to '/matchup'

    patch match_team_lineup_path(@match, @home),
          params: { return_to: 'https://evil.example/', lineup: { lines: { '1' => picked } } }

    assert_redirected_to @matchup_path
  end

  test 'invalid save redirects back with the error' do
    sign_in_as players(:sc_home_captain)

    twice = [players(:sc_home_player1).id, players(:sc_home_player2).id]
    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: { '1' => twice, '2' => twice } } }

    assert_redirected_to @matchup_path
    assert_match(/twice/, flash[:alert])
  end

  test 'subs endpoint lists an out sub dimmed with an undo button and no add button' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', phone: '555-0100', calendar_token: SecureRandom.hex(16))
    MatchAvailability.create!(match_night: @match.match_night, player: sub, status: 'out')
    sign_in_as players(:sc_home_captain)

    get match_team_subs_path(@match, @home)

    row = "tr[data-sub-id='#{sub.id}'] [data-slot=finder] li.opacity-60"

    assert_select sub_rows, "#{row} button[data-status=maybe]", text: 'Undo'
    assert_select sub_rows, "#{row} button[data-action='lineup-move#addSub']", count: 0
    assert_select sub_rows, "#{row} a[href='tel:555-0100']"
  end

  test 'a captain marks an eligible sub out and the opponent captain sees it' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    sign_in_as players(:sc_home_captain)

    patch match_team_sub_path(@match, @home, sub), params: { status: 'out' }

    assert_response :no_content
    assert_equal 'out', @match.match_night.match_availabilities.find_by!(player: sub).status
    sign_in_as players(:sc_away_captain)
    get match_team_subs_path(@match, teams(:sc_away))

    assert_select sub_rows, "tr[data-sub-id='#{sub.id}'] li.opacity-60"
  end

  test 'undo sets an out sub back to maybe' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    MatchAvailability.create!(match_night: @match.match_night, player: sub, status: 'out')
    sign_in_as players(:sc_home_captain)

    patch match_team_sub_path(@match, @home, sub), params: { status: 'maybe' }

    assert_equal 'maybe', @match.match_night.match_availabilities.find_by!(player: sub).status
  end

  test 'a captain cannot mark a sub in' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    sign_in_as players(:sc_home_captain)

    patch match_team_sub_path(@match, @home, sub), params: { status: 'in' }

    assert_response :unprocessable_content
    assert_nil @match.match_night.match_availabilities.find_by(player: sub)
  end

  test 'a rostered player cannot be marked out through the sub endpoint' do
    sign_in_as players(:sc_home_captain)

    patch match_team_sub_path(@match, @home, players(:sc_home_player1)), params: { status: 'out' }

    assert_response :not_found
  end

  test 'the other teams captain cannot mark a sub out for this team' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    sign_in_as players(:sc_away_captain)

    patch match_team_sub_path(@match, @home, sub), params: { status: 'out' }

    assert_redirected_to match_path(@match)
  end

  test 'sub status is locked once the night is canceled' do
    sub = Player.create!(first_name: 'Dana', last_name: 'Sub', calendar_token: SecureRandom.hex(16))
    @match.match_night.update!(canceled: true)
    sign_in_as players(:sc_home_captain)

    patch match_team_sub_path(@match, @home, sub), params: { status: 'out' }

    assert_redirected_to match_path(@match)
  end

  test 'odds endpoint previews money lines for an unsaved lineup' do
    LineupPick.create!(match: @match, team: teams(:sc_away), player: players(:sc_away_player1), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: teams(:sc_away), player: players(:sc_away_player2), position: 1, seat: 2)
    sign_in_as players(:sc_home_captain)
    ids = [players(:sc_home_player1).id, players(:sc_home_player2).id]

    get match_team_odds_path(@match, @home), params: { lineup: { lines: { '1' => ids } } }

    assert_response :success
    assert_equal %w[lines mine theirs], response.parsed_body.keys.sort
  end

  test 'odds endpoint returns nothing for a lineup that could not be saved' do
    sign_in_as players(:sc_home_captain)
    twice = [players(:sc_home_player1).id, players(:sc_home_player2).id]

    get match_team_odds_path(@match, @home), params: { lineup: { lines: { '1' => twice, '2' => twice } } }

    assert_empty response.parsed_body
  end

  test 'odds endpoint is closed to the other teams captain' do
    sign_in_as players(:sc_away_captain)

    get match_team_odds_path(@match, @home)

    assert_redirected_to match_path(@match)
  end

  test 'away captain cannot set the home lineup' do
    sign_in_as players(:sc_away_captain)

    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: {} } }

    assert_redirected_to match_path(@match)
  end

  test 'a team not in the match is not found' do
    sign_in_as players(:sc_home_captain)

    patch match_team_lineup_path(@match, teams(:sc_other)), params: { lineup: { lines: {} } }

    assert_response :not_found
  end

  test 'redirects when the match already has scorecard lineups' do
    sign_in_as players(:sc_home_captain)
    @match.lineups.create!(position: 1)

    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: {} } }

    assert_redirected_to match_path(@match)
  end

  test 'redirects when the night is canceled' do
    sign_in_as players(:sc_home_captain)
    @match.match_night.update!(canceled: true)

    patch match_team_lineup_path(@match, @home), params: { lineup: { lines: {} } }

    assert_redirected_to match_path(@match)
  end

  test 'schedule shows a captain only their own set-lineup link' do
    sign_in_as players(:sc_home_captain)

    get season_match_nights_path(@match.season)

    assert_select "a[href='#{@matchup_path}']"
    assert_select "a[href*='team_id=#{teams(:sc_away).id}']", count: 0
  end

  test 'schedule shows an admin both set-lineup links' do
    sign_in_as players(:zoe)

    get season_match_nights_path(@match.season)

    assert_select "a[href='#{@matchup_path}']"
    assert_select "a[href*='team_id=#{teams(:sc_away).id}']"
  end

  test 'schedule shows a plain player no set-lineup links' do
    sign_in_as players(:sc_home_player1)

    get season_match_nights_path(@match.season)

    assert_select "a[href*='team_id=']", count: 0
  end

  test 'match page hides set-lineup links once results are entered' do
    sign_in_as players(:zoe)
    @match.lineups.create!(position: 1)

    get match_path(@match)

    assert_select "a[href*='match_id=']", count: 0
  end

  private

  def sub_rows
    Nokogiri::HTML5("<table><tbody>#{response.body}</tbody></table>")
  end
end
