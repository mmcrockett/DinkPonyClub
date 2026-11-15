require 'test_helper'

class PhotosControllerTest < ActionDispatch::IntegrationTest
  test 'uploads multiple photos and serves them only to signed-in players' do
    sign_in_as
    night = match_nights(:fall_week_one)

    assert_difference -> { night.photos.attachments.count }, 2 do
      post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg'), photo_upload('two.jpg')] }
    end

    photo = night.photos.attachments.first

    assert_redirected_to match_night_path(night)

    get match_night_photo_path(night, photo)

    assert_response :success
    assert_equal 'private, no-store', response.headers['Cache-Control']

    delete sign_out_path
    get match_night_photo_path(night, photo)

    assert_redirected_to root_path
  end

  test 'requires sign-in to upload photos' do
    night = match_nights(:fall_week_one)

    assert_no_difference -> { night.photos.attachments.count } do
      post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg')] }
    end

    assert_redirected_to root_path
  end

  test 'rejects unsupported photo types' do
    sign_in_as
    night = match_nights(:fall_week_one)
    svg = Rack::Test::UploadedFile.new(StringIO.new('<svg/>'), 'image/svg+xml', original_filename: 'photo.svg')

    assert_no_difference -> { night.photos.attachments.count } do
      post match_night_photos_path(night), params: { photos: [svg] }
    end

    assert_redirected_to match_night_path(night)
    assert_match 'must be a PNG, JPEG or WebP image', flash[:alert]
  end

  test 'only admins can remove photos' do
    sign_in_as
    night = match_nights(:fall_week_one)
    night.photos.attach(io: StringIO.new('photo bytes'), filename: 'photo.jpg', content_type: 'image/jpeg')
    photo = night.photos.attachments.first

    delete match_night_photo_path(night, photo)

    assert_redirected_to root_path
    assert photo.reload

    sign_in_as(players(:zoe))
    delete match_night_photo_path(night, photo)

    assert_redirected_to match_night_path(night)
    assert_not ActiveStorage::Attachment.exists?(photo.id)
  end

  test 'renders uploaded photos on the match-night page' do
    sign_in_as
    night = match_nights(:fall_week_one)
    night.photos.attach(io: StringIO.new('photo bytes'), filename: 'final.jpg', content_type: 'image/jpeg')
    photo = night.photos.attachments.first

    get match_night_path(night)

    assert_response :success
    assert_select 'img[src=?][alt=?]', match_night_photo_path(night, photo), 'final.jpg'
  end

  private

  def photo_upload(filename)
    Rack::Test::UploadedFile.new(StringIO.new('photo bytes'), 'image/jpeg', original_filename: filename)
  end
end
