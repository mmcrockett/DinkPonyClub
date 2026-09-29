require 'test_helper'

class MatchNightsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test 'redirects to root when signed out' do
    get match_nights_path

    assert_redirected_to root_path
  end

  test 'index renders nights in chronological order' do
    sign_in_as_ada

    get match_nights_path

    assert_response :success
    assert_operator response.body.index(dom_id(match_nights(:fall_week_one))),
                    :<, response.body.index(dom_id(match_nights(:fall_playoff)))
  end

  test 'marks the first upcoming night as up next' do
    sign_in_as_ada

    get match_nights_path

    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Up next/i
  end

  test 'shows a final pill for a completed night and scheduled for an upcoming one' do
    sign_in_as_ada

    get match_nights_path

    assert_select "##{dom_id(match_nights(:fall_week_one))}", text: /Final/
    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Scheduled/
  end

  test 'shows canceled and playoffs pills' do
    sign_in_as_ada

    get match_nights_path

    assert_select "##{dom_id(match_nights(:fall_canceled))}", text: /Canceled/
    assert_select "##{dom_id(match_nights(:fall_playoff))}", text: /Playoffs/
  end

  test 'hides team availability for a non-captain' do
    sign_in_as(players(:grace))

    get match_nights_path(view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}", count: 0
  end

  test 'shows team availability for a captain' do
    sign_in_as_ada

    get match_nights_path(view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'shows team availability for an admin' do
    sign_in_as(players(:zoe))

    get match_nights_path(view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'disables the availability select for a team the captain does not control' do
    sign_in_as_ada

    get match_nights_path(view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} select:not([disabled])", minimum: 1
    assert_select "#{frame} select[disabled]", minimum: 1
  end

  test 'scopes the list to the requested season' do
    sign_in_as_ada

    get match_nights_path(season: seasons(:spring).id)

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}", count: 0
  end

  test 'show renders the single night' do
    sign_in_as_ada

    get match_night_path(match_nights(:fall_week_one))

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}"
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
