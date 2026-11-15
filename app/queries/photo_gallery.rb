# frozen_string_literal: true

class PhotoGallery
  PER_PAGE = 24

  attr_reader :page

  def initialize(season: nil, page: 1)
    raise ArgumentError, 'Page must be a positive integer.' unless page.is_a?(Integer) && page.positive?

    @season = season
    @page = page
  end

  def photos
    @photos ||= if page > total_pages
                  []
                else
                  attachments.order(created_at: :desc, id: :desc)
                             .limit(PER_PAGE).offset((page - 1) * PER_PAGE)
                             .preload(:blob, record: :season).to_a
                end
  end

  def total_count
    @total_count ||= attachments.count
  end

  def total_pages
    (total_count + PER_PAGE - 1) / PER_PAGE
  end

  private

  def attachments
    nights = @season ? @season.match_nights : MatchNight.all
    ActiveStorage::Attachment.where(record_type: 'MatchNight', name: 'photos', record_id: nights.select(:id))
  end
end
