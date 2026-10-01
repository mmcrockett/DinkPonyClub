require 'test_helper'

module Admin
  class PaymentRequestsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    test 'redirects a non-admin' do
      sign_in_as players(:ada)

      assert_no_enqueued_emails do
        post admin_payment_requests_path(season: seasons(:fall))
      end

      assert_redirected_to root_path
    end

    test 'emails every player who owes and skips those who are paid up' do
      sign_in_as players(:zoe)

      assert_enqueued_emails 1 do
        post admin_payment_requests_path(season: seasons(:fall))
      end

      assert_redirected_to admin_players_path(season: seasons(:fall))
      assert_equal 'Payment request sent to 1 player.', flash[:notice]
    end

    test 'emails one player' do
      sign_in_as players(:zoe)

      assert_enqueued_emails 1 do
        post admin_player_payment_request_path(players(:ada), season: seasons(:fall))
      end

      assert_redirected_to edit_admin_player_path(players(:ada), season: seasons(:fall))
    end

    test 'sends nothing to a player who owes nothing' do
      sign_in_as players(:zoe)

      assert_no_enqueued_emails do
        post admin_player_payment_request_path(players(:grace), season: seasons(:fall))
      end

      assert_equal 'No payment requests sent.', flash[:notice]
    end

    test 'names players with no email on file' do
      sign_in_as players(:zoe)
      spot = RosterSpot.find_by!(season: seasons(:fall), player: players(:ben))
      spot.charges.create!(fee: fees(:fall_hat), amount_cents: 1000)

      post admin_payment_requests_path(season: seasons(:fall))

      assert_includes flash[:notice], 'No email on file for Ben Stubfield.'
    end

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
