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
  end
end
