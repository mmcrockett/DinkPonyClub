# frozen_string_literal: true

class MatchSlot < ApplicationRecord
  belongs_to :match_night
  has_many :slot_availabilities, dependent: :destroy

  validates :position, presence: true, uniqueness: { scope: :match_night_id }
  validates :starts_at, presence: true, uniqueness: { scope: :match_night_id }

  scope :ordered, -> { order(:starts_at) }

  def label
    starts_at.strftime('%-l:%M %p')
  end
end
