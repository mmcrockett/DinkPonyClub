require 'test_helper'

module Admin
  class FeesControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin' do
      sign_in_as players(:ada)

      get admin_fees_path

      assert_redirected_to root_path
    end

    test 'lists the season fees for an admin' do
      sign_in_as players(:zoe)

      get admin_fees_path(season: seasons(:fall))

      assert_response :success
      assert_select 'li', text: /League fee/
      assert_select 'li', text: /Hat/
    end

    test 'adds a fee mid-season and charges everyone for it' do
      sign_in_as players(:zoe)
      spots = seasons(:fall).roster_spots.count

      assert_difference('Charge.count', spots) do
        post admin_fees_path(season: seasons(:fall)),
             params: { fee: { name: 'Food', amount: '12.50', applies_to_all: '1' } }
      end

      assert_redirected_to admin_fees_path(season: seasons(:fall))
      assert_equal 1250, Fee.find_by!(name: 'Food').amount_cents
    end

    test 'rejects an invalid fee' do
      sign_in_as players(:zoe)

      assert_no_difference('Fee.count') do
        post admin_fees_path(season: seasons(:fall)), params: { fee: { name: '', amount: 'x' } }
      end

      assert_response :unprocessable_content
    end

    test 'removes a fee and its charges' do
      sign_in_as players(:zoe)

      assert_difference('Charge.count', -2) do
        delete admin_fee_path(fees(:fall_league_fee), season: seasons(:fall))
      end

      assert_redirected_to admin_fees_path(season: seasons(:fall))
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
