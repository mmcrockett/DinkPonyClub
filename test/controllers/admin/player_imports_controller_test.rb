require 'test_helper'

module Admin
  class PlayerImportsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin from the form' do
      sign_in_as players(:ada)

      get new_admin_player_import_path

      assert_redirected_to root_path
    end

    test 'redirects a non-admin from importing' do
      sign_in_as players(:ada)

      assert_no_difference 'Player.count' do
        post admin_player_import_path, params: { player_import: { lines: 'x@example.test, X Y' } }
      end
    end

    test 'shows the form to an admin' do
      sign_in_as players(:zoe)

      get new_admin_player_import_path

      assert_response :success
    end

    test 'imports players and reports the counts' do
      sign_in_as players(:zoe)
      lines = "new@example.test, New Person\nada@example.test, Ada\nbad\n"

      assert_difference 'Player.count', 1 do
        post admin_player_import_path, params: { player_import: { lines: lines } }
      end

      assert_equal 'Read 3 imports, added 1 users, 1 already existed, 1 was junk.', flash[:notice]
    end
  end
end
