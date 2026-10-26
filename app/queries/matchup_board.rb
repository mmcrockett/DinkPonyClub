# frozen_string_literal: true

class MatchupBoard
  Row = Data.define(:player, :pupr, :rating, :sub)

  EMPTY_ROW = Row.new(player: nil, pupr: nil, rating: nil, sub: false)
  MIN_SEATS = 2

  def initialize(match, team)
    @match = match
    @team = team
  end

  def opponent
    @match.home_team_id == @team.id ? @match.away_team : @match.home_team
  end

  def lines
    @lines ||= picks.map { |position, ids| [position, line_rows(ids)] }
  end

  def bench
    @bench ||= (roster - picked_players).map { |player| row_for(player) }
                                        .sort_by { |row| -(row.pupr || 0) }
  end

  def sub_options
    @sub_options ||= form.pickable_subs(sub_statuses).map { |player| row_for(player) }
  end

  def picked_subs
    @picked_subs ||= form.subs.map { |player| row_for(player) }
  end

  private

  def form
    @form ||= LineupPlanForm.from_match(@match, @team)
  end

  def picks
    form.lines
  end

  def line_rows(ids)
    rows = ids.map { |id| row_for(players.fetch(id.to_i)) }
    rows.fill(EMPTY_ROW, rows.size...MIN_SEATS)
  end

  def row_for(player)
    rating = ratings.for(player.id)
    Row.new(player: player, pupr: rating&.pupr, rating: rating&.elo&.round, sub: roster.exclude?(player))
  end

  def sub_statuses
    @match.match_night.match_availabilities.where(player: form.eligible_subs).to_h { |row| [row.player_id, row.status] }
  end

  def players
    @players ||= Player.where(id: picks.values.flatten).index_by(&:id)
  end

  def picked_players
    players.values
  end

  def roster
    @roster ||= form.roster
  end

  def ratings
    @ratings ||= PlayerRatings.new(@match.season)
  end
end
