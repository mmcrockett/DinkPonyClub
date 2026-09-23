require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'signs in a player whose email is on the roster' do
    mock_google_auth(email: players(:ada).email)

    post '/auth/google_oauth2'
    follow_redirect!

    assert_redirected_to profile_path
    follow_redirect!

    assert_select 'h1', text: players(:ada).full_name
  end

  test 'rejects a Google account with no matching player' do
    mock_google_auth(email: 'stranger@example.test')

    post '/auth/google_oauth2'
    follow_redirect!

    assert_redirected_to root_path
    assert_equal 'That Google account is not on the Dink Pony Club roster.', flash[:alert]
    assert_nil session[:player_id]
  end

  test 'rejects an unverified Google email' do
    mock_google_auth(email: players(:ada).email, verified: false)

    post '/auth/google_oauth2'
    follow_redirect!

    assert_redirected_to root_path
    assert_nil session[:player_id]
  end

  test 'sign out clears the session' do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!

    delete sign_out_path

    assert_redirected_to root_path
    assert_nil session[:player_id]
  end

  test 'omniauth failure redirects home with an alert' do
    get auth_failure_path, params: { message: 'invalid_credentials' }

    assert_redirected_to root_path
    assert_equal 'Google sign-in failed. Please try again.', flash[:alert]
  end
end
