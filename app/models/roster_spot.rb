# frozen_string_literal: true

class RosterSpot < ApplicationRecord
  belongs_to :season
  belongs_to :team
  belongs_to :player
  has_many :charges, dependent: :destroy

  validates :player_id, uniqueness: { scope: :season_id }

  after_create :add_everyone_fees

  scope :captains, -> { where(captain: true) }

  private

  def add_everyone_fees
    season.fees.where(applies_to_all: true).find_each do |fee|
      charges.create!(fee: fee, amount_cents: fee.amount_cents)
    end
  end
end
