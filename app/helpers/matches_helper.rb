# frozen_string_literal: true

module MatchesHelper
  def pair_names(line, side, game_index, players_by_id)
    line.game_player_ids(side, game_index).filter_map { |id| players_by_id[id]&.full_name }.join(' / ')
  end
end
