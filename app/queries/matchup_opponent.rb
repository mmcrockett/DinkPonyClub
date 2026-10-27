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
    players.fetch(position, []).map { |player| @ratings.elo_for(player.id) }
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
    MatchupBoard::Row.build(player, @ratings.for(player.id), sub: roster.exclude?(player))
  end

  def roster
    @roster ||= @team.roster_for(@match.season).to_a
  end
end
