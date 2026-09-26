# frozen_string_literal: true

class SlotAvailability < ApplicationRecord
  belongs_to :match_slot
  belongs_to :player

  enum :preference, { thumbs_down: 'thumbs_down', meh: 'meh', thumbs_up: 'thumbs_up' }

  validates :player_id, uniqueness: { scope: :match_slot_id }
end
