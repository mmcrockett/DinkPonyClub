# frozen_string_literal: true

class MatchNight < ApplicationRecord
  belongs_to :season
  has_many :matches, dependent: :destroy
  has_many :match_availabilities, dependent: :destroy
  has_many :match_slots, -> { order(:starts_at) }, dependent: :destroy, inverse_of: :match_night
  has_many :slot_availabilities, through: :match_slots

  validates :played_on, presence: true
  validates :label, presence: true

  scope :chronological, -> { order(:played_on) }
  scope :upcoming, -> { where(played_on: Date.current..) }

  AVAILABILITY_CUTOFF_HOUR = 12

  def availability_cutoff_at
    played_on&.in_time_zone&.change(hour: AVAILABILITY_CUTOFF_HOUR)
  end

  def availability_open?
    played_on.present? && Time.current < availability_cutoff_at
  end

  def complete?
    matches.any? && matches.all?(&:complete?)
  end
end
