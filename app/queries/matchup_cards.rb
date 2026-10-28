# frozen_string_literal: true

class MatchupCards
  Side = Data.define(:team, :record, :pupr, :odds)
  Card = Data.define(:match, :home, :away)

  def initialize(match_night, ratings:, records:)
    @match_night = match_night
    @ratings = ratings
    @records = records
  end

  def cards
    @cards ||= matches.map { |match| card_for(match) }
  end

  private

  def matches
    @match_night.matches.includes(:home_team, :away_team).order(:id).to_a
  end

  def card_for(match)
    home = lines(match, match.home_team)
    away = lines(match, match.away_team)
    odds = moneylines(match, home, away)
    Card.new(match: match, home: side(match.home_team, home, odds&.fetch(:mine)),
             away: side(match.away_team, away, odds&.fetch(:theirs)))
  end

  def moneylines(match, home, away)
    by_position = match.line_positions.index_with { |position| [elos(home[position]), elos(away[position])] }
    MatchOdds.new(lines: by_position, sweep_bonus: match.season.sweep_bonus).moneylines
  end

  def side(team, lines, odds)
    ratings = lines.values.flatten.filter_map { |id| @ratings.for(id) }
    Side.new(team: team, record: @records[team.id], pupr: MatchupSummary.mean(ratings.map(&:pupr), 2), odds: odds)
  end

  def elos(ids)
    ids.to_a.map { |id| @ratings.elo_for(id) }
  end

  def lines(match, team)
    picks.fetch([match.id, team.id], {})
  end

  def picks
    @picks ||= LineupPick.where(match_id: @match_night.matches.select(:id)).ordered
                         .pluck(:match_id, :team_id, :position, :player_id)
                         .each_with_object({}) do |(match_id, team_id, position, player_id), found|
      ((found[[match_id, team_id]] ||= {})[position] ||= []) << player_id
    end
  end
end
