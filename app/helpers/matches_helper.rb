# frozen_string_literal: true

module MatchesHelper
  def pair_names(line, side, game_index, players_by_id)
    line.game_player_ids(side, game_index).filter_map { |id| players_by_id[id]&.short_name }.join(' & ')
  end

  def side_names(ids, players_by_id)
    ids.filter_map { |id| players_by_id[id]&.short_name }.join(' & ')
  end

  def roster_options(roster, selected, subs = [])
    return options_for_select(player_choices(roster), selected) if subs.empty?

    grouped_options_for_select([[t('matches.line_players.roster'), player_choices(roster)],
                                [t('matches.line_players.subs'), player_choices(subs)]], selected)
  end

  private

  def player_choices(players)
    players.map { |player| [player.full_name, player.id, { data: { short: player.short_name } }] }
  end
end
