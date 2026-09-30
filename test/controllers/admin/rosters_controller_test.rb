require 'test_helper'

module Admin
  class RostersControllerTest < ActionDispatch::IntegrationTest
    test 'redirects to root when signed out' do
      get admin_roster_path

      assert_redirected_to root_path
    end

    test 'redirects a non-admin away from the roster screen' do
      sign_in_as players(:ada)

      get admin_roster_path(season: seasons(:fall))

      assert_redirected_to root_path
    end

    test 'does not let a non-admin change captains' do
      sign_in_as players(:ada)

      patch admin_roster_path, params: { season: seasons(:fall).id, captain_ids: [roster_spots(:fall_bravo_sam).id] }

      assert_redirected_to root_path
      assert_not roster_spots(:fall_bravo_sam).reload.captain?
    end

    test 'renders every team with a captain checkbox per rostered player' do
      sign_in_as players(:zoe)

      get admin_roster_path(season: seasons(:fall))

      assert_select "##{dom_id(teams(:alpha), :roster)}", text: /#{players(:grace).full_name}/
      assert_select "##{dom_id(teams(:bravo), :roster)}", text: /#{players(:ben).full_name}/
      assert_select "input[type=checkbox][name='captain_ids[]']", count: 4
      assert_select "##{dom_id(roster_spots(:fall_alpha_ada), :captain)}[checked]"
      assert_select "##{dom_id(roster_spots(:fall_alpha_grace), :captain)}:not([checked])"
    end

    test 'shows the draft rank when one is set' do
      roster_spots(:fall_alpha_grace).update!(draft_rank: 'A2')
      sign_in_as players(:zoe)

      get admin_roster_path(season: seasons(:fall))

      assert_select "##{dom_id(roster_spots(:fall_alpha_grace))}", text: /A2/
    end

    test 'renders an empty state for a season with no roster' do
      season = Season.create!(name: 'Empty Season', starts_on: Date.new(2027, 1, 1))
      sign_in_as players(:zoe)

      get admin_roster_path(season: season)

      assert_response :success
      assert_select 'p', text: I18n.t('admin.rosters.show.empty')
    end

    test 'sets and unsets captains' do
      sign_in_as players(:zoe)

      patch admin_roster_path,
            params: { season: seasons(:fall).id, captain_ids: ['', roster_spots(:fall_bravo_sam).id] }

      assert_redirected_to admin_roster_path(season: seasons(:fall))
      assert_predicate roster_spots(:fall_bravo_sam).reload, :captain?
      assert_not roster_spots(:fall_alpha_ada).reload.captain?
    end

    test 'unsets every captain when no box is ticked' do
      sign_in_as players(:zoe)

      patch admin_roster_path, params: { season: seasons(:fall).id, captain_ids: [''] }

      assert_empty seasons(:fall).roster_spots.captains
    end

    test 'keeps two captains on one team' do
      sign_in_as players(:zoe)

      patch admin_roster_path, params: {
        season: seasons(:fall).id,
        captain_ids: [roster_spots(:fall_alpha_ada).id, roster_spots(:fall_alpha_grace).id]
      }

      assert_predicate roster_spots(:fall_alpha_ada).reload, :captain?
      assert_predicate roster_spots(:fall_alpha_grace).reload, :captain?
    end

    test 'leaves other seasons untouched' do
      sign_in_as players(:zoe)

      patch admin_roster_path, params: { season: seasons(:fall).id, captain_ids: [''] }

      assert_not roster_spots(:fall_alpha_ada).reload.captain?
      assert_predicate roster_spots(:spring_alpha_ada).reload, :captain?
    end

    test 'ignores roster spot ids from another season' do
      sign_in_as players(:zoe)

      patch admin_roster_path, params: {
        season: seasons(:spring).id,
        captain_ids: [roster_spots(:spring_alpha_ada).id, roster_spots(:fall_bravo_sam).id]
      }

      assert_not roster_spots(:fall_bravo_sam).reload.captain?
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
