require 'application_system_test_case'

class PhotoUploadTest < ApplicationSystemTestCase
  test 'clearing the file input does not upload' do
    night = match_nights(:fall_week_one)
    sign_in_as players(:ada), return_to: match_night_path(match_nights(:fall_week_one))

    assert_no_button 'Upload photos'

    assert_no_difference -> { night.photos.attachments.count } do
      page.execute_script(<<~JS)
        document.querySelector('input[type=file]').dispatchEvent(new Event('change', { bubbles: true }))
      JS
    end
  end

  test 'uploads a photo immediately after selection' do
    night = match_nights(:fall_week_one)
    sign_in_as players(:ada), return_to: match_night_path(night)

    assert_difference -> { night.photos.attachments.count }, 1 do
      attach_file 'Choose photos', Rails.public_path.join('icon.png')

      assert_text 'Photos uploaded.'
    end
    find('img[alt="icon.png"]', visible: :all).evaluate_script("this.loading = 'eager'")
    assert_selector 'img[alt="icon.png"]', visible: :all do |image|
      image.evaluate_script('this.complete && this.naturalWidth > 0')
    end

    assert_difference -> { night.photos.attachments.count }, -1 do
      accept_confirm { click_button 'Remove photo' }

      assert_text 'Photo removed.'
    end
  end
end
