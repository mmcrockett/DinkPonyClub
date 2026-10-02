# frozen_string_literal: true

module CurrentAvailabilities
  extend ActiveSupport::Concern

  private

  def current_player_availabilities(match_nights)
    MatchAvailability.where(player: current_player, match_night_id: match_nights.map(&:id)).index_by(&:match_night_id)
  end
end
