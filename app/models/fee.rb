# frozen_string_literal: true

class Fee < ApplicationRecord
  belongs_to :season
  has_many :charges, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :season_id }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  after_create :charge_roster, if: :applies_to_all?

  def amount=(dollars)
    self.amount_cents = Dollars.to_cents(dollars)
  end

  private

  def charge_roster
    season.roster_spots.find_each { |spot| spot.charges.create!(fee: self, amount_cents: amount_cents) }
  end
end
