# frozen_string_literal: true

class MatchupOpponent
  def initialize(match, team, ratings)
    @match = match
    @team = team
    @ratings = ratings
  end

  def rows
    @rows ||= players.map do |position, found|
      lines = found.map { |player| row_for(player) }
      [position, lines.fill(MatchupBoard::EMPTY_ROW, lines.size...MatchupBoard::MIN_SEATS)]
    end
  end

  def team_summary
    MatchupSummary.build(players.values.flatten, @ratings)
  end

  def elos(position)
    players.fetch(position, []).map { |player| @ratings.for(player.id)&.elo || PlayerRatings::BASE }
  end

  private

  def players
    @players ||= begin
      lines = LineupPlanForm.from_match(@match, @team).lines
      found = Player.where(id: lines.values.flatten).index_by(&:id)
      lines.transform_values { |ids| ids.filter_map { |id| found[id.to_i] } }
    end
  end

  def row_for(player)
    rating = @ratings.for(player.id)
    MatchupBoard::Row.new(player: player, pupr: rating&.pupr, rating: rating&.elo&.round,
                          sub: roster.exclude?(player), status: nil, preferences: {})
  end

  def roster
    @roster ||= @team.roster_for(@match.season).to_a
  end
end
