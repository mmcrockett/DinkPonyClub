require 'test_helper'

module Admin
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @night = match_nights(:scorecard_week_one)
      @match = matches(:scorecard_match)
    end

    test 'redirects a non-admin and changes nothing' do
      sign_in_as players(:ada)

      assert_no_difference 'Match.count' do
        delete admin_match_night_match_path(@night, @match)
      end
      assert_redirected_to root_path
    end

    test 'adds a matchup in the night season' do
      sign_in_as players(:zoe)

      assert_difference '@night.matches.count', 1 do
        post admin_match_night_matches_path(@night),
             params: { match: { home_team_id: teams(:sc_other).id, away_team_id: teams(:sc_home).id } }
      end

      assert_redirected_to edit_admin_match_night_path(@night)
      assert_equal @night.season, @night.matches.find_by!(home_team: teams(:sc_other)).season
    end

    test 'changes the teams of a matchup' do
      sign_in_as players(:zoe)

      patch admin_match_night_match_path(@night, @match), params: { match: { away_team_id: teams(:sc_other).id } }

      assert_equal teams(:sc_other), @match.reload.away_team
    end

    test 'rejects the same team on both sides' do
      sign_in_as players(:zoe)

      patch admin_match_night_match_path(@night, @match), params: { match: { away_team_id: teams(:sc_home).id } }

      assert_equal teams(:sc_away), @match.reload.away_team
      assert_match(/Could not save matchup/, flash[:alert])
    end

    test 'removes a matchup' do
      sign_in_as players(:zoe)

      assert_difference 'Match.count', -1 do
        delete admin_match_night_match_path(@night, @match)
      end
    end

    test 'refuses to remove a matchup on a night with games' do
      sign_in_as players(:zoe)
      match = matches(:fall_alpha_bravo)

      assert_no_difference 'Match.count' do
        delete admin_match_night_match_path(match.match_night, match)
      end
      assert_match(/games on record/, flash[:alert])
    end

    test 'refuses to add a matchup to a night with games' do
      sign_in_as players(:zoe)

      assert_no_difference 'Match.count' do
        post admin_match_night_matches_path(match_nights(:fall_week_one)),
             params: { match: { home_team_id: teams(:alpha).id, away_team_id: teams(:bravo).id } }
      end
      assert_match(/games on record/, flash[:alert])
    end

    test 'refuses to update a matchup on a night with games' do
      sign_in_as players(:zoe)
      match = matches(:fall_alpha_bravo)

      patch admin_match_night_match_path(match.match_night, match),
            params: { match: { away_team_id: teams(:alpha).id } }

      assert_equal teams(:bravo), match.reload.away_team
    end

    test 'refuses to add a matchup to a canceled night' do
      sign_in_as players(:zoe)

      assert_no_difference 'Match.count' do
        post admin_match_night_matches_path(match_nights(:fall_canceled)),
             params: { match: { home_team_id: teams(:alpha).id, away_team_id: teams(:bravo).id } }
      end
      assert_match(/is canceled/, flash[:alert])
    end

    test 'refuses to update a matchup on a canceled night' do
      sign_in_as players(:zoe)
      night = match_nights(:fall_canceled)
      match = night.matches.create!(season: night.season, home_team: teams(:alpha), away_team: teams(:bravo))

      patch admin_match_night_match_path(night, match), params: { match: { away_team_id: teams(:alpha).id } }

      assert_equal teams(:bravo), match.reload.away_team
      assert_match(/is canceled/, flash[:alert])
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
