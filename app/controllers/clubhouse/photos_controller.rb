# frozen_string_literal: true

module Clubhouse
  class PhotosController < BaseController
    def index
      if request.query_parameters['image']
        photo = ClubhousePhoto.find(request.query_parameters['image'])
        response.headers['X-Content-Type-Options'] = 'nosniff'
        send_data photo.image_data, type: photo.content_type, disposition: 'inline',
                                    filename: "league-photo-#{photo.id}"
      else
        offset = [request.query_parameters['offset'].to_i, 0].max
        query = ClubhousePhoto.select(:id, :player_id, :caption, :created_at).includes(:player)
        rows = query.order(created_at: :desc, id: :desc).offset(offset).limit(25).to_a
        render json: { photos: rows.first(24).map { |photo| serialize_photo(photo) },
                       nextOffset: rows.size > 24 ? offset + 24 : nil }
      end
    end

    def create
      file = params[:photo]
      unless file.respond_to?(:read) && file.size.between?(
        1, 8.megabytes
      )
        return render json: { error: 'Choose a photo under 8 MB.' },
                      status: :unprocessable_content
      end

      bytes = file.read
      type = if bytes.start_with?("\xFF\xD8\xFF".b)
               'image/jpeg'
             elsif bytes.start_with?("\x89PNG\r\n\x1A\n".b)
               'image/png'
             elsif bytes.start_with?('RIFF') && bytes.byteslice(8, 4) == 'WEBP'
               'image/webp'
             end
      return render json: { error: 'Choose a JPEG, PNG, or WebP photo.' }, status: :unprocessable_content unless type

      ClubhousePhoto.create!(player: current_player, caption: params[:caption].to_s.strip.first(500),
                             content_type: type, image_data: bytes)
      render json: { ok: true }, status: :created
    end

    def destroy
      photo = ClubhousePhoto.find(params.expect(:id))
      unless access.admin? || photo.player_id == current_player.id
        return render json: { error: 'Only the uploader or organizer can delete this photo.' },
                      status: :forbidden
      end

      photo.destroy!
      render json: { ok: true }
    end

    private

    def serialize_photo(photo)
      { id: photo.id.to_s, caption: photo.caption, author: photo.player.full_name,
        createdAt: photo.created_at.iso8601, canDelete: access.admin? || photo.player_id == current_player.id }
    end
  end
end
