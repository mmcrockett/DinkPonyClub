# frozen_string_literal: true

class Season < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :teams, -> { distinct }, through: :roster_spots
  has_many :matches, dependent: :destroy
  has_many :match_nights, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :chronological, -> { order(:starts_on) }
  scope :current, -> { where(starts_on: ..Date.current).where(ends_on: Date.current..).order(:starts_on) }
end
