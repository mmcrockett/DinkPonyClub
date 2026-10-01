require 'test_helper'

module Admin
  class MatchNightsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin and leaves the night unchanged' do
      sign_in_as players(:ada)

      patch admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to root_path
      assert_not match_nights(:fall_upcoming).reload.canceled?
    end

    test 'cancels a night for an admin' do
      sign_in_as players(:zoe)

      patch admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to match_nights_path(season: seasons(:fall).id)
      assert_equal 'Week 2 canceled.', flash[:notice]
      assert_predicate match_nights(:fall_upcoming).reload, :canceled?
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
