require 'test_helper'

module Admin
  class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    test 'redirects a non-admin from the form' do
      sign_in_as players(:ada)

      get new_admin_announcement_path(season: seasons(:fall))

      assert_redirected_to root_path
    end

    test 'redirects a non-admin from sending' do
      sign_in_as players(:ada)

      assert_no_enqueued_emails do
        post admin_announcement_path(season: seasons(:fall)), params: { announcement: valid_params }
      end

      assert_redirected_to root_path
    end

    test 'shows the form to an admin' do
      sign_in_as players(:zoe)

      get new_admin_announcement_path(season: seasons(:fall))

      assert_response :success
      assert_select 'input[name="announcement[subject]"]'
    end

    test 'emails each emailed roster player' do
      sign_in_as players(:zoe)
      expected = seasons(:fall).players.active.where.not(email: nil).count

      assert_enqueued_emails expected do
        post admin_announcement_path(season: seasons(:fall)), params: { announcement: valid_params }
      end

      assert_redirected_to new_admin_announcement_path(season: seasons(:fall))
    end

    test 'emails all active players' do
      sign_in_as players(:zoe)
      expected = Player.active.where.not(email: nil).count

      params = { announcement: valid_params.merge(audience: 'all') }

      assert_enqueued_emails expected do
        post admin_announcement_path(season: seasons(:fall)), params: params
      end
    end

    test 'rejects a blank subject' do
      sign_in_as players(:zoe)

      assert_no_enqueued_emails do
        post admin_announcement_path(season: seasons(:fall)), params: { announcement: valid_params.merge(subject: '') }
      end

      assert_response :unprocessable_content
    end

    test 'names players with no email on file' do
      sign_in_as players(:zoe)

      post admin_announcement_path(season: seasons(:fall)), params: { announcement: valid_params }

      assert_includes flash[:notice], 'No email on file for Ben Stubfield.'
    end

    def valid_params
      { subject: 'Rain out', body: "Tonight is cancelled.\nSee you next week.", audience: 'roster' }
    end

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
