require 'test_helper'

class CalendarTokensControllerTest < ActionDispatch::IntegrationTest
  test 'redirects to root when signed out' do
    post profile_calendar_token_path

    assert_redirected_to root_path
    assert_equal 'ada-calendar-token', players(:ada).reload.calendar_token
  end

  test 'regenerates the signed-in player token and revokes the old feed URL' do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!

    post profile_calendar_token_path

    assert_redirected_to profile_path
    new_token = players(:ada).reload.calendar_token

    assert_not_equal 'ada-calendar-token', new_token
    assert_equal 'grace-calendar-token', players(:grace).reload.calendar_token

    get schedule_calendar_path(token: 'ada-calendar-token')

    assert_response :not_found

    get schedule_calendar_path(token: new_token)

    assert_response :success
  end
end
