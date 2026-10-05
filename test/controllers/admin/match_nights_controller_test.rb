require 'test_helper'

module Admin
  class MatchNightsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin away from new and create' do
      sign_in_as players(:ada)

      get new_admin_match_night_path

      assert_redirected_to root_path

      assert_no_difference 'MatchNight.count' do
        post admin_match_nights_path, params: { match_night: { played_on: '2026-11-01', label: 'Week 9' } }
      end
      assert_redirected_to root_path
    end

    test 'edit redirects a non-admin' do
      sign_in_as players(:ada)

      get edit_admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to root_path
    end

    test 'edit shows slot and matchup forms on a live night' do
      sign_in_as players(:zoe)

      get edit_admin_match_night_path(match_nights(:fall_upcoming))

      assert_select "button[aria-label^='Remove']", count: 3
      assert_select "select[aria-label='Home team']", minimum: 2
      assert_select 'input[type=date]', count: 1
    end

    test 'edit locks the date, times, and matchups on a night with games' do
      sign_in_as players(:zoe)

      get edit_admin_match_night_path(match_nights(:fall_week_one))

      assert_select 'input[type=date]', count: 0
      assert_select 'input[type=time]', count: 0
      assert_select 'select', count: 0
      assert_select 'p', text: /Test Team Alpha\s+vs\s+Test Team Bravo/
    end

    test 'edit hides times and matchups on a canceled night' do
      sign_in_as players(:zoe)

      get edit_admin_match_night_path(match_nights(:fall_canceled))

      assert_response :success
      assert_select 'input[type=time]', count: 0
      assert_select 'select', count: 0
    end

    test 'new renders the add night form' do
      sign_in_as players(:zoe)

      get new_admin_match_night_path(season: seasons(:fall))

      assert_response :success
      assert_select "input[name='match_night[played_on]']"
    end

    test 'edit offers cancel on a live night only' do
      sign_in_as players(:zoe)

      get edit_admin_match_night_path(match_nights(:fall_upcoming))

      assert_select 'button', text: 'Cancel night'

      get edit_admin_match_night_path(match_nights(:fall_week_one))

      assert_select 'button', text: 'Cancel night', count: 0
    end

    test 'refuses to cancel a night with games' do
      sign_in_as players(:zoe)

      patch cancel_admin_match_night_path(match_nights(:fall_week_one))

      assert_predicate flash[:alert], :present?
      assert_not match_nights(:fall_week_one).reload.canceled?
    end

    test 'refuses a date change on a night with games but allows a rename' do
      sign_in_as players(:zoe)
      night = match_nights(:fall_week_one)
      original = night.played_on

      patch admin_match_night_path(night), params: { match_night: { label: 'Opener', played_on: original + 7 } }

      assert_predicate flash[:alert], :present?
      assert_equal original, night.reload.played_on

      patch admin_match_night_path(night), params: { match_night: { label: 'Opener' } }

      assert_equal 'Opener', night.reload.label
    end

    test 'adds a night for an admin' do
      sign_in_as players(:zoe)

      assert_difference 'seasons(:fall).match_nights.count', 1 do
        post admin_match_nights_path(season: seasons(:fall)),
             params: { match_night: { played_on: '2026-11-01', label: 'Week 9', venue: 'Rec Center', playoff: '1' } }
      end

      assert_redirected_to season_match_nights_path(seasons(:fall))
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
      assert_select "input[name='match_night[played_on]']"
    end

    test 'redirects to players with an alert when no season exists' do
      sign_in_as players(:zoe)
      Season.destroy_all

      get new_admin_match_night_path

      assert_redirected_to admin_players_path
      assert_equal 'No seasons exist yet.', flash[:alert]
    end

    test 'redirects a non-admin and leaves the night unchanged' do
      sign_in_as players(:ada)

      patch cancel_admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to root_path
      assert_not match_nights(:fall_upcoming).reload.canceled?
    end

    test 'cancels a night for an admin' do
      sign_in_as players(:zoe)

      patch cancel_admin_match_night_path(match_nights(:fall_upcoming))

      assert_redirected_to season_match_nights_path(seasons(:fall))
      assert_equal 'Week 2 canceled.', flash[:notice]
      assert_predicate match_nights(:fall_upcoming).reload, :canceled?
    end

    test 'renames a night for an admin' do
      sign_in_as players(:zoe)

      patch admin_match_night_path(match_nights(:fall_upcoming)), params: { match_night: { label: 'Week 3' } }

      assert_redirected_to edit_admin_match_night_path(match_nights(:fall_upcoming))
      assert_equal 'Week 3 updated.', flash[:notice]
      assert_equal 'Week 3', match_nights(:fall_upcoming).reload.label
    end

    test 'changes the date for an admin and moves its slots' do
      sign_in_as players(:zoe)
      night = match_nights(:fall_upcoming)
      new_date = night.played_on + 7

      patch admin_match_night_path(night), params: { match_night: { label: night.label, played_on: new_date } }

      assert_redirected_to edit_admin_match_night_path(night)
      assert_equal new_date, night.reload.played_on
      assert_equal [new_date], night.match_slots.map { |slot| slot.starts_at.in_time_zone.to_date }.uniq
    end

    test 'rejects a blank date' do
      sign_in_as players(:zoe)
      night = match_nights(:fall_upcoming)
      original = night.played_on

      patch admin_match_night_path(night), params: { match_night: { label: night.label, played_on: '' } }

      assert_predicate flash[:alert], :present?
      assert_equal original, night.reload.played_on
    end

    test 'rejects a blank rename' do
      sign_in_as players(:zoe)

      patch admin_match_night_path(match_nights(:fall_upcoming)), params: { match_night: { label: '' } }

      assert_redirected_to edit_admin_match_night_path(match_nights(:fall_upcoming))
      assert_predicate flash[:alert], :present?
      assert_equal 'Week 2', match_nights(:fall_upcoming).reload.label
    end

    test 'redirects a non-admin rename and leaves the label and date unchanged' do
      sign_in_as players(:ada)
      night = match_nights(:fall_upcoming)
      original = night.played_on

      patch admin_match_night_path(night), params: { match_night: { label: 'Hacked', played_on: original + 7 } }

      assert_redirected_to root_path
      assert_equal 'Week 2', night.reload.label
      assert_equal original, night.played_on
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
