# frozen_string_literal: true

module PlayersHelper
  LineSummary = Struct.new(:match, :opponent, :partners, :scores, :wins, :losses, keyword_init: true)

  def win_rate_label(row)
    return '-' if row.nil? || row.win_pct.nil?

    number_to_percentage(row.win_pct * 100, precision: 0)
  end

  def player_team_label(row)
    row.substitute? ? t('players.card.substitute') : row.team.name
  end

  def can_edit_player?(player)
    player == current_player || admin?
  end

  def player_line_summary(player, lineup, games)
    home = games.first.home_players.include?(player)
    match = lineup.match
    scores = own_side_scores(games, home)
    wins = scores.count { |own, other| own > other }

    LineSummary.new(match:, opponent: home ? match.away_team : match.home_team,
                    partners: line_partners(games, home) - [player],
                    scores:, wins:, losses: scores.size - wins)
  end

  private

  def own_side_scores(games, home)
    games.map { |game| home ? [game.home_score, game.away_score] : [game.away_score, game.home_score] }
  end

  def line_partners(games, home)
    games.flat_map { |game| home ? game.home_players : game.away_players }.uniq
  end
end
