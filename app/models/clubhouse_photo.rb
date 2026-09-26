# frozen_string_literal: true

class ClubhousePhoto < ApplicationRecord
  belongs_to :player
  validates :caption, length: { maximum: 500 }
  validates :content_type, inclusion: { in: %w[image/jpeg image/png image/webp] }
  validates :image_data, presence: true
  validate do
    errors.add(:image_data, 'is too large') if image_data && image_data.bytesize > 8.megabytes
  end
end
