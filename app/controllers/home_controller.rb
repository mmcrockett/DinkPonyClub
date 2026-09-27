# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return unless signed_in?

    season = Season.current.first || Season.chronological.last
    return unless season

    @next_match = current_player.next_match(season)
    return unless @next_match

    @match_slots = @next_match.match_slots
    @availability = @next_match.match_availabilities.find_or_initialize_by(player: current_player)
    @slot_availabilities = @next_match.slot_availabilities.where(player: current_player).index_by(&:match_slot_id)
  end
end
