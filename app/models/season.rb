# frozen_string_literal: true

class Season < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :teams, -> { distinct }, through: :roster_spots
  has_many :matches, dependent: :destroy
  has_many :match_nights, dependent: :destroy
  has_many :fees, dependent: :destroy

  MAX_LINES = 5

  validates :name, presence: true, uniqueness: true
  validates :lines_per_match, numericality: { only_integer: true, in: 1..MAX_LINES }

  scope :chronological, -> { order(:starts_on) }
  scope :current, -> { where(starts_on: ..Date.current).where(ends_on: Date.current..).order(:starts_on) }

  def self.default
    current.first || chronological.last
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end
end
