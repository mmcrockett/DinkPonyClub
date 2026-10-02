require 'test_helper'

class MatchNightsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test 'redirects to root when signed out' do
    get season_match_nights_path(seasons(:fall))

    assert_redirected_to root_path
  end

  test 'index renders nights in chronological order' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_response :success
    assert_operator response.body.index(dom_id(match_nights(:fall_week_one))),
                    :<, response.body.index(dom_id(match_nights(:fall_playoff)))
  end

  test 'marks the first upcoming night as up next' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Up next/i
  end

  test 'shows a final pill for a completed night and scheduled for an upcoming one' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_week_one))}", text: /Final/
    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Scheduled/
  end

  test 'shows canceled and playoffs pills' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_canceled))}", text: /Canceled/
    assert_select "##{dom_id(match_nights(:fall_playoff))}", text: /Playoffs/
  end

  test 'hides team availability for a non-captain' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}", count: 0
  end

  test 'shows team availability for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'team view drops the personal availability buttons so each player is set in one place' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :my_availability)}", count: 0
  end

  test 'matchups view keeps the personal availability buttons' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"
  end

  test 'highlights only the saved answer when availability is closed for a non-captain' do
    sign_in_as(players(:grace))

    travel_to(match_nights(:fall_upcoming).availability_cutoff_at + 1.minute) do
      get season_match_nights_path(seasons(:fall))
    end

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[type=radio]", count: 0
    assert_select "#{frame} span.bg-red-700", text: 'Out'
    assert_select "#{frame} span.bg-dpc-green, #{frame} span.bg-amber-400", count: 0
  end

  test 'leaves every personal button unselected on a night the player has not answered' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_playoff), :my_availability)}"

    assert_select "#{frame} input[type=radio]", minimum: 3
    assert_select "#{frame} input[type=radio][checked]", count: 0
  end

  test 'team view shows ??? for players who have not answered and counts them separately' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} option[selected][disabled][value='']", text: '???', minimum: 1
    assert_select "#{frame} p", text: /\d+ in \u00b7 \d+ maybe \u00b7 [1-9]\d* \?\?\?/
  end

  test 'shows team availability for an admin' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'disables the availability select for a team the captain does not control' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} select:not([disabled])", minimum: 1
    assert_select "#{frame} select[disabled]", minimum: 1
  end

  test 'scopes the list to the requested season' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:spring))

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}", count: 0
  end

  test 'show renders the single night' do
    sign_in_as_ada

    get match_night_path(match_nights(:fall_week_one))

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}"
  end

  test 'links a completed match to its scorecard for a plain player' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_week_one))} a[href=?]", match_path(matches(:fall_alpha_bravo)),
                  text: 'Scorecard'
  end

  test 'shows an enter results link on an unplayed match for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]", edit_match_path(matches(:fall_future)),
                  text: 'Enter results'
  end

  test 'shows an enter results link on an unplayed match for an admin' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]", edit_match_path(matches(:fall_future))
  end

  test 'hides the enter results link from a plain player' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]", edit_match_path(matches(:fall_future)),
                  count: 0
  end

  test 'links a completed match to its scorecard rather than the edit form for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_week_one))}"

    assert_select "#{frame} a[href=?]", match_path(matches(:fall_alpha_bravo))
    assert_select "#{frame} a[href=?]", edit_match_path(matches(:fall_alpha_bravo)), count: 0
  end

  test 'shows a cancel button to an admin on a live night only' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} button", text: 'Cancel night'
    assert_select "##{dom_id(match_nights(:fall_canceled))} button", text: 'Cancel night', count: 0
  end

  test 'hides the availability control on a canceled night' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_canceled), :my_availability)}", count: 0
  end

  test 'hides cancel buttons from a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select 'button', text: 'Cancel night', count: 0
  end

  test 'treats a player deactivated mid-session as signed out' do
    sign_in_as_ada
    players(:ada).inactive!

    get season_match_nights_path(seasons(:fall))

    assert_redirected_to root_path
  end

  private

  def sign_in_as_ada
    sign_in_as(players(:ada))
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
