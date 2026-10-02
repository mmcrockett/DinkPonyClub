# frozen_string_literal: true

class SlotAvailability < ApplicationRecord
  belongs_to :match_slot
  belongs_to :player

  # Declaration order is the display order of the picker.
  enum :preference, { thumbs_up: 'thumbs_up', meh: 'meh', thumbs_down: 'thumbs_down' }

  validates :player_id, uniqueness: { scope: :match_slot_id }
end
