# frozen_string_literal: true

module UpNext
  extend ActiveSupport::Concern
  include SlotPreferences
  include CurrentAvailabilities

  private

  def load_up_next(season)
    @next_match_night = season.match_nights.upcoming.where(canceled: false).chronological
                              .includes(MatchNightsController::MATCH_NIGHT_INCLUDES).first
    @can_enter_results = captain_or_admin?(season)
    @availabilities = current_player_availabilities([@next_match_night].compact)
    @slot_preferences = current_player_slot_preferences([@next_match_night].compact)
  end
end
