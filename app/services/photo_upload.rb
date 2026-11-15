# frozen_string_literal: true

require 'vips'

class PhotoUpload
  class InvalidImage < StandardError; end
  class TooLarge < StandardError; end

  MAX_PIXELS = 60_000_000
  MAX_DIMENSION = 1600
  FORMATS = {
    'VipsForeignLoadJpegFile' => ['jpg', 'image/jpeg'],
    'VipsForeignLoadPngFile' => ['png', 'image/png'],
    'VipsForeignLoadWebpFile' => ['webp', 'image/webp'],
    'VipsForeignLoadHeifFile' => ['jpg', 'image/jpeg']
  }.freeze

  def initialize(match_night:, uploads:, player:)
    @match_night = match_night
    @uploads = uploads
    @player = player
    @blobs = []
  end

  def call
    attached = false
    @uploads.each { |upload| process(upload) }
    @match_night.transaction do
      @match_night.photos.attach(@blobs)
      @match_night.save!
    end
    attached = true
  ensure
    @blobs.each(&:purge) unless attached
  end

  private

  def process(upload)
    raise TooLarge if upload.size > MatchNight::MAX_PHOTO_BYTES

    format, image = read_image(upload)
    write_blob(upload, image, *format)
  rescue Vips::Error => e
    Rails.logger.info("Photo processing failed: #{e.message}")
    raise InvalidImage
  end

  def read_image(upload)
    format = FORMATS[Vips.vips_foreign_find_load(upload.tempfile.path)]
    raise InvalidImage unless format

    image = Vips::Image.new_from_file(upload.tempfile.path, access: :sequential, fail_on: :error)
    raise TooLarge if image.width * image.height > MAX_PIXELS

    [format, image]
  end

  def write_blob(upload, image, extension, content_type)
    Tempfile.create(['photo', ".#{extension}"]) do |file|
      image = image.autorot.thumbnail_image(MAX_DIMENSION, height: MAX_DIMENSION, size: :down).colourspace(:srgb)
      save_image(image, file.path, extension)
      raise TooLarge if file.size > MatchNight::MAX_PHOTO_BYTES

      store_blob(upload, file, extension, content_type)
    end
  end

  def store_blob(upload, file, extension, content_type)
    file.rewind
    filename = "#{File.basename(upload.original_filename, File.extname(upload.original_filename))}.#{extension}"
    blob = ActiveStorage::Blob.create_after_unfurling!(
      io: file, filename: filename, content_type: content_type, identify: false,
      metadata: { uploaded_by_player_id: @player.id }
    )
    @blobs << blob
    blob.upload_without_unfurling(file)
  end

  def save_image(image, path, extension)
    case extension
    when 'jpg'
      image = image.flatten(background: [255, 255, 255]) if image.has_alpha?
      image.jpegsave(path, Q: 82, strip: true)
    when 'png'
      image.pngsave(path, strip: true)
    when 'webp'
      image.webpsave(path, Q: 82, strip: true)
    end
  end
end
