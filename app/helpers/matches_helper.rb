# frozen_string_literal: true

module MatchesHelper
  def pair_names(line, side, game_index, players_by_id)
    line.game_player_ids(side, game_index).filter_map { |id| players_by_id[id]&.short_name }.join(' & ')
  end

  def roster_options(roster, selected)
    choices = roster.map { |player| [player.full_name, player.id, { data: { short: player.short_name } }] }
    options_for_select(choices, selected)
  end
end
