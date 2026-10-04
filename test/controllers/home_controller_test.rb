require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test 'signed out shows a sign-in prompt and no league data' do
    get root_path

    assert_response :success
    assert_select 'a[href=?]', sign_in_path
    assert_select "##{dom_id(match_nights(:fall_upcoming))}", count: 0
    assert_select 'table', count: 0
  end

  test 'shows the up-next night card with personal availability at the top' do
    sign_in_as(players(:ada))

    get root_path

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Up next/i
    assert_select "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"
    assert_select "##{dom_id(match_nights(:fall_week_one))}", count: 0
  end

  test 'shows the current season standings below the card' do
    sign_in_as(players(:ada))

    get root_path

    assert_select "tr##{dom_id(teams(:alpha), :standings)}"
    assert_operator response.body.index(dom_id(match_nights(:fall_upcoming))),
                    :<, response.body.index(dom_id(teams(:alpha), :standings))
  end

  test 'shows no card when nothing is coming up' do
    sign_in_as(players(:ada))

    travel_to(MatchNight.maximum(:played_on) + 1.day) { get root_path }

    assert_select '[id^=match_night_]', count: 0
    assert_select "tr##{dom_id(teams(:alpha), :standings)}"
  end

  test 'skips a canceled night when picking what is up next' do
    sign_in_as(players(:ada))
    match_nights(:fall_upcoming).update!(canceled: true)

    get root_path

    assert_select "##{dom_id(match_nights(:fall_upcoming))}", count: 0
  end

  test 'signed in during Fall 2026 shows the lineups banner' do
    sign_in_as(players(:ada))

    get root_path

    assert_select 'img[alt=?]', I18n.t('home.index.banner_alt')
  end

  test 'signed in during another season hides the lineups banner' do
    sign_in_as(players(:ada))

    get root_path(season: seasons(:summer))

    assert_select 'img[alt=?]', I18n.t('home.index.banner_alt'), count: 0
  end

  test 'signed out hides the lineups banner' do
    get root_path

    assert_select 'img[alt=?]', I18n.t('home.index.banner_alt'), count: 0
  end

  private

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
