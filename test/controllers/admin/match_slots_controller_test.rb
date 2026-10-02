require 'test_helper'

module Admin
  class MatchSlotsControllerTest < ActionDispatch::IntegrationTest
    setup { @night = match_nights(:fall_upcoming) }

    test 'redirects a non-admin and creates nothing' do
      sign_in_as players(:ada)

      assert_no_difference 'MatchSlot.count' do
        post admin_match_night_match_slots_path(@night), params: { match_slot: { starts_at: '18:00' } }
      end
      assert_redirected_to root_path
    end

    test 'redirects a non-admin and removes nothing' do
      sign_in_as players(:ada)

      assert_no_difference 'MatchSlot.count' do
        delete admin_match_night_match_slot_path(@night, match_slots(:fall_future_slot_one))
      end
      assert_redirected_to root_path
    end

    test 'adds a slot on the night date in central time after the last position' do
      sign_in_as players(:zoe)

      assert_difference '@night.match_slots.count', 1 do
        post admin_match_night_match_slots_path(@night), params: { match_slot: { starts_at: '18:15' } }
      end

      slot = @night.match_slots.find_by!(position: 4)

      assert_redirected_to admin_match_nights_path(season: @night.season)
      assert_equal [@night.played_on, '18:15'], [slot.starts_at.to_date, slot.starts_at.strftime('%H:%M')]
    end

    test 'rejects a blank time with an alert' do
      sign_in_as players(:zoe)

      assert_no_difference 'MatchSlot.count' do
        post admin_match_night_match_slots_path(@night), params: { match_slot: { starts_at: '' } }
      end

      assert_redirected_to admin_match_nights_path(season: @night.season)
      assert_match(/Could not add time/, flash[:alert])
    end

    test 'removes a slot and its availabilities' do
      sign_in_as players(:zoe)
      slot = match_slots(:fall_future_slot_one)

      assert_difference ['MatchSlot.count', 'SlotAvailability.count'], -1 do
        delete admin_match_night_match_slot_path(@night, slot)
      end

      assert_redirected_to admin_match_nights_path(season: @night.season)
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
