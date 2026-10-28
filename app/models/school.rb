# frozen_string_literal: true

class School < ApplicationRecord
  ICON_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_ICON_BYTES = 1.megabyte

  has_many :players, dependent: :nullify
  has_one_attached :icon

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validate :icon_is_small_image

  scope :by_name, -> { order(:name) }

  private

  def icon_is_small_image
    return unless icon.attached?

    errors.add(:icon, :invalid) unless ICON_TYPES.include?(icon.blob.content_type)
    errors.add(:icon, :too_big) if icon.blob.byte_size > MAX_ICON_BYTES
  end
end
