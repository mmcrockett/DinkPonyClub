require 'application_system_test_case'

class PhotoUploadTest < ApplicationSystemTestCase
  test 'upload button appears only while photos are selected' do
    sign_in_as players(:ada), return_to: match_night_path(match_nights(:fall_week_one))

    assert_no_button 'Upload photos'
    attach_file 'Choose photos', Rails.public_path.join('icon.png')

    assert_button 'Upload photos'

    page.execute_script(<<~JS)
      const input = document.querySelector('input[type=file]')
      input.value = ''
      input.dispatchEvent(new Event('change', { bubbles: true }))
    JS

    assert_no_button 'Upload photos'
  end

  test 'uploads a selected photo' do
    night = match_nights(:fall_week_one)
    sign_in_as players(:ada), return_to: match_night_path(night)
    attach_file 'Choose photos', Rails.public_path.join('icon.png')

    assert_difference -> { night.photos.attachments.count }, 1 do
      click_button 'Upload photos'

      assert_text 'Photos uploaded.'
    end
  end
end
