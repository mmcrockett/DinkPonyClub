# frozen_string_literal: true

require 'test_helper'

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test 'index links every season to its landing page' do
    get seasons_path

    assert_response :success
    assert_select "a[href='#{season_path(seasons(:fall))}']", text: /#{seasons(:fall).name}/
  end

  test 'show redirects to root when signed out' do
    get season_path(seasons(:fall))

    assert_redirected_to root_path
  end

  test 'show is a 404 for an unknown season' do
    sign_in_as_ada

    get '/seasons/0-nope'

    assert_response :not_found
  end

  test 'show lists the up next night and recent results for that season' do
    sign_in_as_ada

    get season_path(seasons(:fall))

    assert_response :success
    assert_select 'h1', text: seasons(:fall).name
    assert_select "##{ActionView::RecordIdentifier.dom_id(match_nights(:fall_upcoming))}"
    assert_select ".recent-results a[href='#{match_path(matches(:fall_alpha_bravo))}']"
  end

  test 'show up next card lists slot preferences with the saved choice' do
    sign_in_as_ada
    slot = match_slots(:fall_future_slot_one)

    get season_path(seasons(:fall))

    assert_select "input[name='slot_preferences[#{slot.id}]']", count: 3
    assert_select "input[name='slot_preferences[#{slot.id}]'][value=thumbs_up][checked]"
  end

  test 'show standings include streak and next opponent' do
    sign_in_as_ada

    get season_path(seasons(:fall))

    assert_select "tr#standings_team_#{teams(:alpha).id} .streak", text: 'W1'
    assert_select "tr#standings_team_#{teams(:alpha).id} .next-opponent", text: teams(:bravo).name
  end

  test 'show scopes to the requested season and the breadcrumb switches seasons' do
    sign_in_as_ada

    get season_path(seasons(:spring))

    assert_select 'h1', text: seasons(:spring).name
    assert_select "nav[aria-label=Breadcrumb] a[href='#{season_path(seasons(:fall))}']", text: seasons(:fall).name
  end

  private

  def sign_in_as_ada
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
