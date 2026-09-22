# frozen_string_literal: true

class Season < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :players, through: :roster_spots
  has_many :teams, -> { distinct }, through: :roster_spots

  validates :name, presence: true, uniqueness: true

  scope :chronological, -> { order(:starts_on) }
end
