# frozen_string_literal: true

module UpNext
  extend ActiveSupport::Concern

  private

  def load_up_next(season)
    @next_match_night = season.match_nights.upcoming.where(canceled: false).chronological
                              .includes(MatchNightsController::MATCH_NIGHT_INCLUDES).first
    @can_enter_results = captain_or_admin?(season)
    @availabilities = availabilities_for(@next_match_night)
  end

  def availabilities_for(match_night)
    return {} unless match_night

    availability = match_night.match_availabilities.find { |a| a.player_id == current_player.id }
    availability ? { match_night.id => availability } : {}
  end
end
