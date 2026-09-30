require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'redirects to root when signed out' do
    get profile_path

    assert_redirected_to root_path
  end

  test 'renders the profile when signed in' do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!

    get profile_path

    assert_response :success
    assert_select 'h1', text: players(:ada).full_name
    assert_select "a[href='#{edit_player_path(players(:ada))}']", text: 'Edit contact details'
  end

  test 'shows the private calendar feed links and reset button' do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!

    get profile_path

    token = players(:ada).calendar_token

    assert_select "input[value='http://www.example.com/schedule.ics?token=#{token}']"
    assert_select "a[href='webcal://www.example.com/schedule.ics?token=#{token}']"
    assert_select "form[action='#{profile_calendar_token_path}'] button", text: 'Reset link'
    assert_select '#calendar_feed', text: /Anyone with this link can see your schedule/
  end
end
