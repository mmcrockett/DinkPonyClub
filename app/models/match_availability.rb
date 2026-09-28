# frozen_string_literal: true

class MatchAvailability < ApplicationRecord
  belongs_to :match_night
  belongs_to :player

  enum :status, { in: 'in', maybe: 'maybe', out: 'out' }, scopes: false

  validates :player_id, uniqueness: { scope: :match_night_id }
end
