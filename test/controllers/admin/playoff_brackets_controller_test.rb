require 'test_helper'

module Admin
  class PlayoffBracketsControllerTest < ActionDispatch::IntegrationTest
    setup { @setup = build_playoff_season }

    test 'redirects a non-admin and seeds nothing' do
      sign_in_as players(:ada)

      assert_no_difference 'Match.count' do
        post admin_match_night_playoff_bracket_path(@setup.night)
      end
    end

    test 'seeds the semifinals for an admin' do
      sign_in_as players(:zoe)

      assert_difference '@setup.night.matches.count', 2 do
        post admin_match_night_playoff_bracket_path(@setup.night)
      end
      assert_redirected_to edit_admin_match_night_path(@setup.night)
    end

    test 'creates the final after the semifinals have games on record' do
      sign_in_as players(:zoe)
      League::PlayoffBracket.new(@setup.night).seed!
      @setup.night.matches.each { |match| score_match!(match, @setup.players, sweep(11, 5)) }

      assert_difference '@setup.night.matches.count', 1 do
        post final_admin_match_night_playoff_bracket_path(@setup.night)
      end
    end

    test 'alerts when the final is not ready' do
      sign_in_as players(:zoe)

      post final_admin_match_night_playoff_bracket_path(@setup.night)

      assert_equal 'Both semifinals must be complete', flash[:alert]
    end
  end
end
