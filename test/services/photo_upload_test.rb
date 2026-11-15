require 'test_helper'
class PhotoUploadServiceTest < ActiveSupport::TestCase
  test 'cleans up blobs if storage upload fails' do
    upload = photo_upload
    service = PhotoUpload.new(match_night: match_nights(:fall_week_one), uploads: [upload], player: players(:ada))
    storage = ActiveStorage::Blob.service
    original_upload = storage.method(:upload)
    storage.define_singleton_method(:upload) { |*, **| raise IOError, 'storage unavailable' }

    assert_no_difference 'ActiveStorage::Blob.count' do
      assert_raises(IOError) { service.call }
    end
  ensure
    storage.define_singleton_method(:upload, original_upload) if original_upload
  end

  test 'cleans up blobs when the match night cannot be saved' do
    night = match_nights(:fall_week_one)
    night.label = nil
    service = PhotoUpload.new(match_night: night, uploads: [photo_upload], player: players(:ada))

    assert_no_difference ['ActiveStorage::Blob.count', 'ActiveStorage::Attachment.count'] do
      assert_raises(ActiveRecord::RecordInvalid) { service.call }
    end
  end

  private

  def photo_upload
    Rack::Test::UploadedFile.new(Rails.public_path.join('icon.png'), 'image/png')
  end
end
