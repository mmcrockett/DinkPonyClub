require 'test_helper'

class SchoolIconsControllerTest < ActionDispatch::IntegrationTest
  test 'serves a school icon without signing in' do
    school = schools(:lincoln)
    school.icon.attach(io: StringIO.new('icon bytes'), filename: 'icon.png', content_type: 'image/png')

    get school_icon_path(school)

    assert_response :success
    assert_equal 'icon bytes', response.body
    assert_equal 'image/png', response.media_type
  end

  test 'returns not found when a school has no icon' do
    get school_icon_path(schools(:lincoln))

    assert_response :not_found
  end
end
