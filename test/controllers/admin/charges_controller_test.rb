require 'test_helper'

module Admin
  class ChargesControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin' do
      sign_in_as players(:ada)

      patch admin_player_charges_path(players(:grace)), params: { season: seasons(:fall).id }

      assert_redirected_to root_path
    end

    test 'edit page shows a row for every season fee' do
      sign_in_as players(:zoe)

      get edit_admin_player_path(players(:ada), season: seasons(:fall))

      assert_select "input[name='charges[#{fees(:fall_league_fee).id}][charged]'][checked]"
      assert_select "input[name='charges[#{fees(:fall_hat).id}][charged]']:not([checked])"
    end

    test 'records a partial payment' do
      sign_in_as players(:zoe)

      update_charges(players(:ada), fees(:fall_league_fee) => { charged: '1', paid: '30.00' })

      assert_equal 3000, charges(:ada_league_fee).reload.paid_cents
    end

    test 'marks a fee paid in full' do
      sign_in_as players(:zoe)

      update_charges(players(:ada), fees(:fall_league_fee) => { charged: '1', paid_in_full: '1' })

      assert_equal 6000, charges(:ada_league_fee).reload.paid_cents
    end

    test 'opts a player into one fee and out of another' do
      sign_in_as players(:zoe)
      league_charge_id = charges(:ada_league_fee).id

      update_charges(players(:ada), fees(:fall_hat) => { charged: '1', paid: '5' })

      assert_not Charge.exists?(league_charge_id)
      assert_equal 500, Charge.find_by!(fee: fees(:fall_hat)).paid_cents
    end

    test 'rejects an unparseable payment and changes nothing' do
      sign_in_as players(:zoe)

      update_charges(players(:ada), fees(:fall_league_fee) => { charged: '1', paid: 'abc' })

      assert_equal 2000, charges(:ada_league_fee).reload.paid_cents
      assert_predicate flash[:alert], :present?
    end

    private

    def update_charges(player, entries)
      patch admin_player_charges_path(player),
            params: { season: seasons(:fall).id, charges: entries.transform_keys(&:id) }
    end

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
