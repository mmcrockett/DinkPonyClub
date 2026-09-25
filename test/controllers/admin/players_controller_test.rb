require 'test_helper'

module Admin
  class PlayersControllerTest < ActionDispatch::IntegrationTest
    test 'redirects to root when signed out' do
      get admin_players_path

      assert_redirected_to root_path
    end

    test 'redirects to root when signed in as a non-admin' do
      sign_in_as players(:ada)

      get admin_players_path

      assert_redirected_to root_path
    end

    test 'renders the player list for an admin' do
      sign_in_as players(:zoe)

      get admin_players_path

      assert_response :success
      assert_select 'li', text: /#{players(:ada).full_name}/
    end

    test 'renders the new player form for an admin' do
      sign_in_as players(:zoe)

      get new_admin_player_path

      assert_response :success
    end

    test 'renders the edit form for an admin' do
      sign_in_as players(:zoe)

      get edit_admin_player_path(players(:ada))

      assert_response :success
    end

    test 'creates a player' do
      sign_in_as players(:zoe)

      params = { player: { first_name: 'New', last_name: 'Player', email: 'new@example.test' } }

      assert_difference('Player.count', 1) do
        post admin_players_path, params: params
      end

      assert_redirected_to admin_players_path
    end

    test 'does not create an invalid player' do
      sign_in_as players(:zoe)

      assert_no_difference('Player.count') do
        post admin_players_path, params: { player: { first_name: '', last_name: '' } }
      end

      assert_response :unprocessable_entity
    end

    test 'updates a player name and email' do
      sign_in_as players(:zoe)

      patch admin_player_path(players(:ada)), params: { player: { first_name: 'Updated', email: 'ada@example.test' } }

      assert_redirected_to admin_players_path
      assert_equal 'Updated', players(:ada).reload.first_name
    end

    test 'ignores an admin param on update' do
      sign_in_as players(:zoe)

      patch admin_player_path(players(:ada)), params: { player: { admin: true } }

      assert_not players(:ada).reload.admin?
    end

    test 'deactivates a player' do
      sign_in_as players(:zoe)

      patch admin_player_path(players(:ada)), params: { player: { status: 'inactive' } }

      assert_predicate players(:ada).reload, :inactive?
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
