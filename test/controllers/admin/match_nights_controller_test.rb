require 'test_helper'

module Admin
  class MatchNightsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin away from the index and create' do
      sign_in_as players(:ada)

      get admin_match_nights_path

      assert_redirected_to root_path

      assert_no_difference 'MatchNight.count' do
        post admin_match_nights_path, params: { match_night: { played_on: '2026-11-01', label: 'Week 9' } }
      end
      assert_redirected_to root_path
    end

    test 'lists the season nights with a cancel button on live ones only' do
      sign_in_as players(:zoe)

      get admin_match_nights_path(season: seasons(:fall))

      assert_select "##{dom_id(match_nights(:fall_upcoming))} button", text: 'Cancel night'
      assert_select "##{dom_id(match_nights(:fall_canceled))} button", count: 0
    end

    test 'adds a night for an admin' do
      sign_in_as players(:zoe)

      assert_difference 'seasons(:fall).match_nights.count', 1 do
        post admin_match_nights_path(season: seasons(:fall)),
             params: { match_night: { played_on: '2026-11-01', label: 'Week 9', venue: 'Rec Center', playoff: '1' } }
      end

      assert_redirected_to admin_match_nights_path(season: seasons(:fall))
      assert_equal 'Week 9 added.', flash[:notice]
      assert_predicate seasons(:fall).match_nights.find_by!(label: 'Week 9'), :playoff?
    end

    test 'rejects a night with no label' do
      sign_in_as players(:zoe)

      assert_no_difference 'MatchNight.count' do
        post admin_match_nights_path(season: seasons(:fall)),
             params: { match_night: { played_on: '2026-11-01', label: '' } }
      end

      assert_response :unprocessable_content
    end

    test 'redirects to players with an alert when no season exists' do
      sign_in_as players(:zoe)
      Season.destroy_all

      get admin_match_nights_path

      assert_redirected_to admin_players_path
      assert_equal 'No seasons exist yet.', flash[:alert]
    end

    test 'redirects a non-admin and leaves the night unchanged' do
      sign_in_as players(:ada)

      patch admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to root_path
      assert_not match_nights(:fall_upcoming).reload.canceled?
    end

    test 'cancels a night for an admin' do
      sign_in_as players(:zoe)

      patch admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to admin_match_nights_path(season: seasons(:fall))
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
