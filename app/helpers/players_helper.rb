# frozen_string_literal: true

module PlayersHelper
  LineSummary = Struct.new(:match, :opponent, :partners, :scores, :wins, :losses, :changes, keyword_init: true)

  def win_rate_label(row)
    return '-' if row.nil? || row.win_pct.nil?

    number_to_percentage(row.win_pct * 100, precision: 0)
  end

  def player_team_label(row)
    row.substitute? ? t('players.substitute') : row.team.name
  end

  def rating_label(row)
    row.rating || '-'
  end

  def pupr_label(row)
    row.pupr ? number_with_precision(row.pupr, precision: 2) : '-'
  end

  def players_period_link(filter, season:, lifetime:, active:)
    label = t(lifetime ? 'players.filters.all_time' : 'players.filters.season')
    classes = active ? 'bg-dpc-navy text-white' : 'bg-white text-dpc-navy hover:bg-gray-100'

    link_to label, players_index_path(season, players_query_params(filter, lifetime: lifetime)),
            class: "px-4 py-2 text-sm font-semibold #{classes}", aria: { current: ('page' if active) }
  end

  def pupr_change_label(change)
    format('%<change>+.2f', change: change.pupr)
  end

  def elo_change_label(change)
    format('%<change>+d', change: change.elo.round)
  end

  def rating_change_class(value)
    if value.positive?
      'text-dpc-green'
    elsif value.negative?
      'text-red-700'
    else
      'text-gray-500'
    end
  end

  def players_sort_link(filter, column, season:, lifetime: false)
    query_params = players_query_params(filter, lifetime: lifetime).merge(sort: column,
                                                                          dir: filter.next_direction(column))

    link_to players_index_path(season, query_params), class: 'inline-flex items-center gap-1 hover:text-dpc-navy' do
      safe_join([t("players.index.table.#{column}"), sort_indicator(filter, column)].compact)
    end
  end

  def players_aria_sort(filter, column)
    return 'none' unless filter.sort == column

    filter.descending? ? 'descending' : 'ascending'
  end

  def player_line_summary(player, lineup, games, ratings)
    home = games.first.home_players.include?(player)
    match = lineup.match
    scores = own_side_scores(games, home)
    wins = scores.count { |own, other| own > other }

    LineSummary.new(match:, opponent: home ? match.away_team : match.home_team,
                    partners: line_partners(games, home) - [player],
                    scores:, wins:, losses: scores.size - wins,
                    changes: changes_for(player, games, ratings))
  end

  private

  def changes_for(player, games, ratings)
    games.map { |game| ratings.change_for(game.id, player.id) }
  end

  def players_index_path(season, query_params)
    season ? season_players_path(season, query_params) : players_path(query_params)
  end

  def players_query_params(filter, lifetime:)
    { q: filter.query.presence, team: filter.team, hide_substitutes: filter.hide_substitutes? ? '1' : nil,
      sort: filter.sort, dir: filter.direction, period: ('lifetime' if lifetime) }.compact
  end

  def sort_indicator(filter, column)
    return unless filter.sort == column

    render 'shared/icon', name: filter.descending? ? 'chevron-down' : 'chevron-up', class: 'h-3 w-3'
  end

  def own_side_scores(games, home)
    games.map { |game| home ? [game.home_score, game.away_score] : [game.away_score, game.home_score] }
  end

  def line_partners(games, home)
    games.flat_map { |game| home ? game.home_players : game.away_players }.uniq
  end
end
