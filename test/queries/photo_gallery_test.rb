require 'test_helper'

class PhotoGalleryTest < ActiveSupport::TestCase
  test 'orders by upload time instead of match-night date with stable ties' do
    old = attach_photos(match_nights(:fall_upcoming)).first
    newer, newest = attach_photos(match_nights(:scorecard_week_one), 2)
    old.update!(created_at: 2.days.ago)
    newer.update!(created_at: 1.day.ago)
    newest.update!(created_at: newer.created_at)

    assert_equal [newest.id, newer.id, old.id], PhotoGallery.new.photos.map(&:id)
  end

  test 'includes all seasons by default and filters when a season is supplied' do
    fall = attach_photos(match_nights(:fall_week_one)).first
    winter = attach_photos(match_nights(:scorecard_week_one)).first

    assert_equal [fall.id, winter.id].sort, PhotoGallery.new.photos.map(&:id).sort
    gallery = PhotoGallery.new(season: seasons(:fall))

    assert_equal [fall.id], gallery.photos.map(&:id)
    assert_equal 1, gallery.total_count
  end

  test 'excludes other attachment names and record types' do
    photo = attach_photos(match_nights(:fall_week_one)).first
    photo.blob.attachments.create!(record: photo.record, name: 'other')
    photo.blob.attachments.create!(record: players(:ada), name: 'photos')

    assert_equal [photo.id], PhotoGallery.new.photos.map(&:id)
  end

  test 'paginates without repeating photos and handles a partial last page' do
    photos = attach_photos(match_nights(:fall_week_one), 25)
    first = PhotoGallery.new
    last = PhotoGallery.new(page: 2)

    assert_equal 24, first.photos.size
    assert_equal 2, first.total_pages
    assert_equal 1, last.photos.size
    assert_empty first.photos.map(&:id) & last.photos.map(&:id)
    assert_equal photos.map(&:id).sort, (first.photos + last.photos).map(&:id).sort
  end

  test 'handles empty seasons and pages beyond the end' do
    attach_photos(match_nights(:fall_week_one))
    empty = PhotoGallery.new(season: seasons(:scorecard))

    assert_empty empty.photos
    assert_equal 0, empty.total_pages
    assert_empty PhotoGallery.new(page: 10**30).photos
  end

  test 'rejects invalid page arguments' do
    [0, -1, '2', nil].each do |page|
      assert_raises(ArgumentError) { PhotoGallery.new(page: page) }
    end
  end

  test 'preloads blobs match nights and seasons for every visible photo' do
    attach_photos(match_nights(:fall_week_one), 2)
    attach_photos(match_nights(:scorecard_week_one))
    photos = PhotoGallery.new.photos

    assert_no_queries do
      photos.each { |photo| [photo.filename, photo.record.label, photo.record.season.name] }
    end
  end

  private

  def attach_photos(night, count = 1)
    night.photos.attach(Array.new(count) do |index|
      { io: StringIO.new('photo bytes'), filename: "#{index}.jpg", content_type: 'image/jpeg' }
    end)
    night.photos.attachments.order(:id).to_a
  end
end
