require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  test 'renders without an availability card when signed out' do
    get root_path

    assert_response :success
    assert_select "form[action='#{match_availability_path(matches(:fall_future))}']", count: 0
  end

  test 'renders the availability form before the cutoff' do
    sign_in_as_ada

    get root_path

    assert_response :success
    assert_select "form[action='#{match_availability_path(matches(:fall_future))}']"
  end

  test 'renders a read-only summary after the cutoff' do
    sign_in_as_ada

    travel_to matches(:fall_future).played_on.in_time_zone.change(hour: 13) do
      get root_path
    end

    assert_response :success
    assert_select "form[action='#{match_availability_path(matches(:fall_future))}']", count: 0
    assert_select 'p', text: 'Contact your captain directly if you need to change.'
  end

  private

  def sign_in_as_ada
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
