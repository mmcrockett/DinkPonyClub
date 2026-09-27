# frozen_string_literal: true

class MatchSlot < ApplicationRecord
  belongs_to :match
  has_many :slot_availabilities, dependent: :destroy

  validates :position, presence: true, uniqueness: { scope: :match_id }
  validates :starts_at, presence: true

  scope :ordered, -> { order(:starts_at) }
end
