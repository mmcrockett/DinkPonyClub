require 'test_helper'
require 'vips'

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

  test 'uploads a photo when the form includes an empty hidden field' do
    sign_in_as
    night = match_nights(:fall_week_one)

    assert_difference -> { night.photos.attachments.count }, 1 do
      post match_night_photos_path(night), params: { photos: ['', photo_upload('one.jpg')] }
    end

    assert_redirected_to match_night_path(night)
  end

  test 'asks for a photo when the form contains only its empty hidden field' do
    sign_in_as
    night = match_nights(:fall_week_one)

    post match_night_photos_path(night), params: { photos: [''] }

    assert_redirected_to match_night_path(night)
    assert_equal 'Choose at least one photo.', flash[:alert]
  end

  test 'rejects signed blob ids in uploads' do
    sign_in_as
    night = match_nights(:fall_week_one)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('photo bytes'), filename: 'photo.jpg',
                                                  content_type: 'image/jpeg')

    assert_no_difference -> { night.photos.attachments.count } do
      post match_night_photos_path(night), params: { photos: ['', blob.signed_id] }
    end

    assert_redirected_to match_night_path(night)
    assert_equal 'Photos must be uploaded as files.', flash[:alert]
  end

  test 'default Active Storage routes cannot bypass photo access' do
    night = match_nights(:fall_week_one)
    night.photos.attach(io: StringIO.new('photo bytes'), filename: 'photo.jpg', content_type: 'image/jpeg')
    signed_id = night.photos.first.blob.signed_id

    get "/rails/active_storage/blobs/redirect/#{signed_id}/photo.jpg"

    assert_response :not_found

    get "/rails/active_storage/blobs/proxy/#{signed_id}/photo.jpg"

    assert_response :not_found

    get "/rails/active_storage/representations/redirect/#{signed_id}/anything/photo.jpg"

    assert_response :not_found

    get '/rails/active_storage/disk/anything/photo.jpg'

    assert_response :not_found
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
    assert_select 'a[href=?] img[src=?][alt=?]', match_night_photo_path(night, photo),
                  thumbnail_match_night_photo_path(night, photo), 'final.jpg'
  end

  test 'serves a bounded thumbnail to signed-in players' do
    sign_in_as
    night = match_nights(:fall_week_one)
    image = Vips::Image.black(1200, 900).write_to_buffer('.png')
    night.photos.attach(io: StringIO.new(image), filename: 'photo.png', content_type: 'image/png')
    photo = night.photos.attachments.first

    get thumbnail_match_night_photo_path(night, photo)

    assert_response :success
    assert_equal 'private, no-store', response.headers['Cache-Control']
    thumbnail = Vips::Image.new_from_buffer(response.body, '')

    assert_equal [600, 450], [thumbnail.width, thumbnail.height]
  end

  test 'thumbnail access requires an active player' do
    sign_in_as
    night = match_nights(:fall_week_one)
    night.photos.attach(io: StringIO.new('photo bytes'), filename: 'photo.jpg', content_type: 'image/jpeg')
    photo = night.photos.attachments.first
    players(:ada).inactive!

    get thumbnail_match_night_photo_path(night, photo)

    assert_redirected_to root_path
  end

  private

  def photo_upload(filename)
    Rack::Test::UploadedFile.new(StringIO.new('photo bytes'), 'image/jpeg', original_filename: filename)
  end
end
