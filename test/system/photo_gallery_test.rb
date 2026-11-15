require 'application_system_test_case'

class PhotoGallerySystemTest < ApplicationSystemTestCase
  test 'paginates and resets to page one when filtering seasons' do
    attach_photos(match_nights(:fall_week_one), 25)
    attach_photos(match_nights(:scorecard_week_one))
    sign_in_as players(:ada), return_to: photos_path

    assert_selector 'figure', count: 24
    click_link 'Next'

    assert_selector 'figure', count: 2
    select seasons(:scorecard).name, from: 'Season'
    click_button 'Apply'

    assert_selector 'figure', count: 1
    assert_no_text 'Page 2'
    assert_text seasons(:scorecard).name
  end

  test 'mobile navigation opens the gallery with working thumbnails and source links' do
    night = match_nights(:fall_week_one)
    attach_photos(night)
    sign_in_as players(:ada)
    page.driver.browser.manage.window.resize_to(390, 844)
    find('button[aria-label="Toggle menu"]').click
    click_link 'Photos'

    assert_current_path photos_path
    assert_selector 'img[alt="0.png"]' do |image|
      image.evaluate_script('this.complete && this.naturalWidth > 0')
    end
    within('figure') { click_link night.label }

    assert_text 'Choose photos'
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private

  def attach_photos(night, count = 1)
    bytes = Rails.public_path.join('icon.png').binread
    night.photos.attach(Array.new(count) do |index|
      { io: StringIO.new(bytes), filename: "#{index}.png", content_type: 'image/png' }
    end)
  end
end
