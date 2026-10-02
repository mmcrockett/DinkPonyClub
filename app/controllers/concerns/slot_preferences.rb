# frozen_string_literal: true

module SlotPreferences
  extend ActiveSupport::Concern

  private

  def current_player_slot_preferences(match_nights)
    slot_ids = match_nights.flat_map { |night| night.match_slots.map(&:id) }
    SlotAvailability.where(player: current_player, match_slot_id: slot_ids).pluck(:match_slot_id, :preference).to_h
  end
end
