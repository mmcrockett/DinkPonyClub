# frozen_string_literal: true

class PhotosController < ApplicationController
  before_action :require_sign_in
  before_action :set_match_night
  before_action :set_photo, only: %i[show thumbnail destroy]
  before_action :require_admin, only: :destroy

  def show
    send_photo @photo.blob
  end

  def thumbnail
    send_photo @photo.variant(:thumbnail).processed
  end

  def create
    uploads = photo_params
    return redirect_to match_night_path(@match_night), alert: upload_error(uploads) if upload_error(uploads)

    @match_night.photos.attach(uploads)
    if @match_night.save
      redirect_to match_night_path(@match_night), notice: t('photos.uploaded')
    else
      redirect_to match_night_path(@match_night), alert: @match_night.errors.full_messages.to_sentence
    end
  end

  def destroy
    @photo.purge
    redirect_to match_night_path(@match_night), notice: t('photos.removed')
  end

  private

  def send_photo(image)
    response.headers['Cache-Control'] = 'private, no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_data image.download, type: image.content_type, disposition: 'inline'
  end

  def set_match_night
    @match_night = MatchNight.find(params.expect(:match_night_id))
  end

  def set_photo
    @photo = @match_night.photos.attachments.find(params.expect(:id))
  end

  def photo_params
    params.expect(photos: []).compact_blank
  end

  def upload_error(uploads)
    return t('photos.select_files') if uploads.blank?

    t('photos.invalid_upload') unless uploads.all?(ActionDispatch::Http::UploadedFile)
  end
end
