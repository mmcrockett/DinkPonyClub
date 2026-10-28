require 'test_helper'

module Admin
  class SchoolsControllerTest < ActionDispatch::IntegrationTest
    test 'redirects a non-admin' do
      sign_in_as players(:ada)

      get admin_schools_path

      assert_redirected_to root_path
    end

    test 'lists schools for an admin' do
      sign_in_as players(:zoe)

      get admin_schools_path

      assert_response :success
      assert_select 'input[value=?]', schools(:lincoln).name
    end

    test 'creates a school with an icon' do
      sign_in_as players(:zoe)
      icon = Rack::Test::UploadedFile.new(StringIO.new('png-bytes'), 'image/png', original_filename: 'icon.png')

      assert_difference('School.count') do
        post admin_schools_path, params: { school: { name: 'Jefferson', icon: icon } }
      end

      assert_predicate School.find_by!(name: 'Jefferson').icon, :attached?
    end

    test 'rejects a blank name' do
      sign_in_as players(:zoe)

      assert_no_difference('School.count') do
        post admin_schools_path, params: { school: { name: '' } }
      end

      assert_response :unprocessable_content
    end

    test 'renames a school' do
      sign_in_as players(:zoe)

      patch admin_school_path(schools(:lincoln)), params: { school: { name: 'Lincoln Prep' } }

      assert_equal 'Lincoln Prep', schools(:lincoln).reload.name
    end

    test 'destroys a school and leaves its players unknown' do
      sign_in_as players(:zoe)
      players(:ada).update!(school: schools(:lincoln))

      assert_difference('School.count', -1) do
        delete admin_school_path(schools(:lincoln))
      end

      assert_nil players(:ada).reload.school_id
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid)
      post '/auth/google_oauth2'
      follow_redirect!
    end
  end
end
