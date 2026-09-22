# frozen_string_literal: true

class RosterSpot < ApplicationRecord
  belongs_to :season
  belongs_to :team
  belongs_to :player

  validates :player_id, uniqueness: { scope: :season_id }

  scope :captains, -> { where(captain: true) }
end
