# frozen_string_literal: true

class Charge < ApplicationRecord
  belongs_to :roster_spot
  belongs_to :fee

  validates :fee_id, uniqueness: { scope: :roster_spot_id }
  validates :amount_cents, :paid_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :paid_within_amount

  scope :owing, -> { where('charges.paid_cents < charges.amount_cents') }

  def self.owing_player_ids(season)
    owing.joins(:roster_spot).where(roster_spots: { season_id: season.id }).distinct.pluck('roster_spots.player_id')
  end

  def self.owing_for(player, season)
    owing.joins(:roster_spot).where(roster_spots: { player_id: player.id,
                                                    season_id: season.id }).includes(:fee).order(:id)
  end

  def balance_cents
    amount_cents - paid_cents
  end

  private

  def paid_within_amount
    return unless amount_cents && paid_cents && paid_cents > amount_cents

    errors.add(:paid_cents, :less_than_or_equal_to, count: amount_cents)
  end
end
