# frozen_string_literal: true

class Player < ApplicationRecord
  has_many :roster_spots, dependent: :destroy
  has_many :teams, through: :roster_spots
  has_many :seasons, through: :roster_spots

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :first_name, :last_name, presence: true
  validates :email, uniqueness: true, allow_nil: true

  scope :by_name, -> { order(:first_name, :last_name) }

  def full_name
    "#{first_name} #{last_name}"
  end
end
