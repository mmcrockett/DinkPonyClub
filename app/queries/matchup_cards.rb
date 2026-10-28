# frozen_string_literal: true

class MatchupCards
  Side = Data.define(:team, :record, :pupr)
  Card = Data.define(:match, :home, :away)

  def initialize(match_night, ratings:, records:)
    @match_night = match_night
    @ratings = ratings
    @records = records
  end

  def cards
    @cards ||= matches.map do |match|
      Card.new(match: match, home: side(match, match.home_team), away: side(match, match.away_team))
    end
  end

  private

  def matches
    @match_night.matches.includes(:home_team, :away_team).order(:id).to_a
  end

  def side(match, team)
    Side.new(team: team, record: @records[team.id], pupr: pupr(picks.fetch([match.id, team.id], [])))
  end

  def pupr(player_ids)
    MatchupSummary.mean(player_ids.filter_map { |id| @ratings.for(id)&.pupr }, 2)
  end

  def picks
    @picks ||= LineupPick.where(match_id: @match_night.matches.select(:id))
                         .pluck(:match_id, :team_id, :player_id)
                         .group_by { |match_id, team_id, _player_id| [match_id, team_id] }
                         .transform_values { |rows| rows.map(&:last) }
  end
end
