require 'test_helper'
require 'vips'

class PhotosControllerTest < ActionDispatch::IntegrationTest
  test 'gallery requires sign-in and rejects inactive players' do
    get photos_path

    assert_redirected_to root_path
    sign_in_as
    players(:ada).inactive!
    get photos_path

    assert_redirected_to root_path
  end

  test 'gallery shows photos across all seasons with authenticated image links and source captions' do
    sign_in_as
    night = match_nights(:fall_week_one)
    fall = attach_gallery_photos(night).first
    attach_gallery_photos(match_nights(:scorecard_week_one))

    get photos_path

    assert_response :success
    assert_select 'figure', count: 2
    assert_select 'a[href=?] img[src=?][alt=?][loading=lazy]', match_night_photo_path(night, fall),
                  thumbnail_match_night_photo_path(night, fall), fall.filename.to_s
    assert_select 'figcaption a[href=?]', match_night_path(night, anchor: 'match-night-photos'), text: night.label
    assert_select 'select[name=season] option[selected]', text: 'All seasons'
  end

  test 'gallery filters to the selected season' do
    sign_in_as
    attach_gallery_photos(match_nights(:fall_week_one))
    attach_gallery_photos(match_nights(:scorecard_week_one))

    get photos_path(season: seasons(:scorecard))

    assert_select 'figure', count: 1
    assert_select 'figcaption span', text: seasons(:scorecard).name
    assert_select 'select[name=season] option[selected]', text: seasons(:scorecard).name
  end

  test 'gallery pagination retains season' do
    sign_in_as
    attach_gallery_photos(match_nights(:fall_week_one), 25)
    season = seasons(:fall)

    get photos_path(season: season)

    assert_select 'figure', count: 24
    assert_select 'a[rel=next][href=?]', photos_path(season: season, page: 2)
    get photos_path(season: season, page: 2)

    assert_select 'figure', count: 1
    assert_select 'a[rel=prev][href=?]', photos_path(season: season, page: 1)
  end

  test 'gallery filter form resets the page' do
    sign_in_as

    get photos_path(season: seasons(:fall), page: 2)

    assert_select 'form[action=?][method=get]', photos_path do
      assert_select '[name=page]', count: 0
    end
  end

  test 'gallery is read-only even for admins and hides single-page pagination' do
    sign_in_as(players(:zoe))
    attach_gallery_photos(match_nights(:fall_week_one))

    get photos_path

    assert_select 'input[type=file]', count: 0
    assert_select 'figure form', count: 0
    assert_select 'nav[aria-label=?]', 'Photo pages', count: 0
  end

  test 'gallery distinguishes empty library and empty season' do
    sign_in_as

    get photos_path

    assert_select 'p', text: 'No photos shared yet.'
    attach_gallery_photos(match_nights(:fall_week_one))
    get photos_path(season: seasons(:scorecard))

    assert_select 'p', text: 'No photos shared for this season yet.'
    assert_select 'select[name=season] option', count: Season.count + 1
  end

  test 'gallery offers a filtered first-page link beyond the end' do
    sign_in_as
    attach_gallery_photos(match_nights(:fall_week_one))

    get photos_path(season: seasons(:fall), page: 10**30)

    assert_response :success
    assert_select 'p', text: 'No photos on this page.'
    assert_select 'a[href=?]', photos_path(season: seasons(:fall)), text: 'Back to the first page'
  end

  test 'gallery rejects missing seasons rather than falling back to the default' do
    sign_in_as

    get photos_path(season: Season.maximum(:id) + 1)

    assert_response :not_found
  end

  test 'gallery rejects malformed and nonpositive pages' do
    sign_in_as
    %w[0 -1 abc 1.5 2x].each do |page|
      get photos_path(page: page)

      assert_response :bad_request
    end
  end

  test 'clearing the season returns to all seasons on page one' do
    sign_in_as
    attach_gallery_photos(match_nights(:fall_week_one))
    attach_gallery_photos(match_nights(:scorecard_week_one))

    get photos_path(season: '')

    assert_response :success
    assert_select 'figure', count: 2
    assert_select 'select[name=season] option[selected]', text: 'All seasons'
  end

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

  test 'converts HEIC to JPEG without storing the original' do
    sign_in_as
    night = match_nights(:fall_week_one)
    upload = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/photo.heic'), 'image/heic')

    assert_difference('ActiveStorage::Blob.count', 1) do
      post match_night_photos_path(night), params: { photos: [upload] }
    end
    blob = night.photos.first.blob

    assert_equal 'image/jpeg', blob.content_type
    assert_equal 'photo.jpg', blob.filename.to_s
    assert_equal [40, 24], image_dimensions(blob)
    assert_equal players(:ada).id, blob.metadata['uploaded_by_player_id']
  end

  test 'resizes JPEG photos without enlarging and removes orientation metadata' do
    sign_in_as
    night = match_nights(:fall_week_one)
    bytes = Vips::Image.black(3000, 1000).write_to_buffer('.jpg')
    exif = "Exif\0\0II".b + [42, 8, 1, 274, 3, 1, 6, 0, 0].pack('vVvvvVvvV')
    bytes = bytes.byteslice(0, 2) + "\xFF\xE1".b + [exif.bytesize + 2].pack('n') + exif + bytes.byteslice(2..)

    post match_night_photos_path(night), params: { photos: [upload_bytes(bytes, 'rotated.jpg', 'image/jpeg')] }
    blob = night.photos.first.blob
    image = Vips::Image.new_from_buffer(blob.download, '')

    assert_equal [533, 1600], [image.width, image.height]
    assert_empty image.get_fields.grep(/exif|orientation/i)
  end

  test 'preserves PNG transparency and format when resizing' do
    sign_in_as
    night = match_nights(:fall_week_one)
    bytes = Vips::Image.black(2400, 1200, bands: 4).write_to_buffer('.png')

    post match_night_photos_path(night), params: { photos: [upload_bytes(bytes, 'transparent.png', 'image/png')] }
    blob = night.photos.first.blob
    image = Vips::Image.new_from_buffer(blob.download, '')

    assert_equal 'image/png', blob.content_type
    assert_equal [1600, 800], [image.width, image.height]
    assert_equal 0, image.getpoint(0, 0).last
  end

  test 'retains WebP format and transparency' do
    sign_in_as
    night = match_nights(:fall_week_one)
    bytes = Vips::Image.black(20, 10, bands: 4).write_to_buffer('.webp')

    post match_night_photos_path(night), params: { photos: [upload_bytes(bytes, 'transparent.webp', 'image/webp')] }
    blob = night.photos.first.blob
    image = Vips::Image.new_from_buffer(blob.download, '')

    assert_equal 'image/webp', blob.content_type
    assert_equal [20, 10], [image.width, image.height]
    assert_equal 0, image.getpoint(0, 0).last
  end

  test 'rejects a mixed batch without leaving new attachments or blobs' do
    sign_in_as
    night = match_nights(:fall_week_one)
    night.photos.attach(io: StringIO.new('existing'), filename: 'existing.jpg', content_type: 'image/jpeg')
    invalid = upload_bytes('<svg/>', 'fake.jpg', 'image/jpeg')

    assert_no_difference ['night.photos.attachments.count', 'ActiveStorage::Blob.count'] do
      post match_night_photos_path(night), params: { photos: [photo_upload('valid.jpg'), invalid] }
    end

    assert_equal 'Photos must be valid JPEG, PNG, WebP or HEIC images.', flash[:alert]
  end

  test 'rejects oversized original files' do
    sign_in_as
    night = match_nights(:fall_week_one)
    oversized = upload_bytes('x' * (MatchNight::MAX_PHOTO_BYTES + 1), 'large.jpg', 'image/jpeg')

    assert_no_difference 'ActiveStorage::Blob.count' do
      post match_night_photos_path(night), params: { photos: [oversized] }
    end

    assert_match '10 MB or smaller', flash[:alert]
  end

  test 'rejects excessively large image dimensions before decoding' do
    sign_in_as
    night = match_nights(:fall_week_one)
    bytes = Vips::Image.black(8000, 8000).write_to_buffer('.png')

    assert_no_difference 'ActiveStorage::Blob.count' do
      post match_night_photos_path(night), params: { photos: [upload_bytes(bytes, 'large.png', 'image/png')] }
    end

    assert_match '60 megapixels', flash[:alert]
  end

  test 'rejects corrupt images' do
    sign_in_as
    night = match_nights(:fall_week_one)
    bytes = Vips::Image.black(10, 10).write_to_buffer('.jpg').byteslice(0, 25)

    assert_no_difference 'ActiveStorage::Blob.count' do
      post match_night_photos_path(night), params: { photos: [upload_bytes(bytes, 'broken.jpg', 'image/jpeg')] }
    end

    assert_equal 'Photos must be valid JPEG, PNG, WebP or HEIC images.', flash[:alert]
  end

  test 'requires sign-in to upload photos' do
    night = match_nights(:fall_week_one)

    assert_no_difference -> { night.photos.attachments.count } do
      post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg')] }
    end

    assert_redirected_to root_path
  end

  test 'records the uploader for every photo in a batch' do
    sign_in_as(players(:ada))
    night = match_nights(:fall_week_one)
    post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg'), photo_upload('two.jpg')] }

    uploader_ids = night.photos.blobs.map { |blob| blob.metadata['uploaded_by_player_id'] }

    assert_equal [players(:ada).id, players(:ada).id], uploader_ids
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
    assert_match 'must be valid JPEG, PNG, WebP or HEIC images', flash[:alert]
  end

  test 'players can remove photos they uploaded' do
    sign_in_as(players(:ada))
    night = match_nights(:fall_week_one)
    post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg')] }
    photo = night.photos.attachments.first

    get match_night_path(night)

    assert_select 'form[action=?][method=post]', match_night_photo_path(night, photo)

    delete match_night_photo_path(night, photo)

    assert_redirected_to match_night_path(night)
    assert_not ActiveStorage::Attachment.exists?(photo.id)
  end

  test 'players cannot remove someone else photo' do
    sign_in_as(players(:ada))
    night = match_nights(:fall_week_one)
    post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg')] }
    photo = night.photos.attachments.first
    sign_in_as(players(:grace))

    get match_night_path(night)

    assert_select 'form[action=?][method=post]', match_night_photo_path(night, photo), count: 0

    delete match_night_photo_path(night, photo)

    assert_redirected_to root_path
    assert_equal 'You can only remove photos you uploaded.', flash[:alert]
    assert ActiveStorage::Attachment.exists?(photo.id)
  end

  test 'admins can remove someone else photo' do
    sign_in_as(players(:ada))
    night = match_nights(:fall_week_one)
    post match_night_photos_path(night), params: { photos: [photo_upload('one.jpg')] }
    photo = night.photos.attachments.first
    sign_in_as(players(:zoe))

    get match_night_path(night)

    assert_select 'form[action=?][method=post]', match_night_photo_path(night, photo)

    delete match_night_photo_path(night, photo)

    assert_redirected_to match_night_path(night)
    assert_not ActiveStorage::Attachment.exists?(photo.id)
  end

  test 'only admins can remove photos without an uploader' do
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

  def attach_gallery_photos(night, count = 1)
    night.photos.attach(Array.new(count) do |index|
      { io: StringIO.new('photo bytes'), filename: "#{index}.jpg", content_type: 'image/jpeg' }
    end)
    night.photos.attachments.order(:id).to_a
  end

  def photo_upload(filename)
    bytes = Vips::Image.black(10, 10).write_to_buffer('.jpg')
    upload_bytes(bytes, filename, 'image/jpeg')
  end

  def upload_bytes(bytes, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, original_filename: filename)
  end

  def image_dimensions(blob)
    image = Vips::Image.new_from_buffer(blob.download, '')
    [image.width, image.height]
  end
end
