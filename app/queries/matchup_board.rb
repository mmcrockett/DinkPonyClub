# frozen_string_literal: true

class MatchupBoard
  Row = Data.define(:player, :pupr, :rating, :sub, :status, :preferences) do
    def self.build(player, rating, sub:, status: nil, preferences: {})
      new(player: player, pupr: rating&.pupr, rating: rating&.elo&.round, sub: sub,
          status: status, preferences: preferences)
    end

    def bench_sort_key
      [status == 'out' ? 1 : 0, -(pupr || 0)]
    end
  end

  EMPTY_ROW = Row.new(player: nil, pupr: nil, rating: nil, sub: false, status: nil, preferences: {})
  MIN_SEATS = 2
  SEATS = LineupPick::SEATS.size

  delegate :bench, to: :opponent_side, prefix: :opponent

  def initialize(match, team, ratings: PlayerRatings.new(match.season))
    @match = match
    @team = team
    @ratings = ratings
  end

  def opponent
    @match.home_team_id == @team.id ? @match.away_team : @match.home_team
  end

  def lines
    @lines ||= picks.map { |position, ids| [position, line_rows(ids)] }
  end

  def bench
    @bench ||= (roster - picked_players).map { |player| row_for(player) }
                                        .sort_by(&:bench_sort_key)
  end

  def opponent_lines
    opponent_side.rows
  end

  def team_summary
    MatchupSummary.build(lines.flat_map { |_position, rows| rows.filter_map(&:player) }, ratings)
  end

  def opponent_team_summary
    opponent_side.team_summary
  end

  def odds(own_ids = nil)
    return build_odds(own_ids) if own_ids

    @odds ||= build_odds(picks)
  end

  def slots
    @slots ||= @match.match_night.match_slots.ordered.to_a
  end

  def sub_options
    @sub_options ||= form.pickable_subs.map { |player| row_for(player) }.sort_by(&:bench_sort_key)
  end

  def picked_subs
    @picked_subs ||= form.subs.map { |player| row_for(player) }
  end

  private

  def form
    @form ||= LineupPlanForm.from_match(@match, @team)
  end

  def opponent_side
    @opponent_side ||= MatchupOpponent.new(@match, opponent, ratings)
  end

  def build_odds(own_ids)
    lines = own_ids.to_h do |position, ids|
      own = ids.map { |id| elo_of(id.to_i) }
      [position, [own, opponent_side.elos(position)]]
    end
    MatchOdds.new(lines: lines, sweep_bonus: @match.season.sweep_bonus)
  end

  def elo_of(player_id)
    ratings.elo_for(player_id)
  end

  def picks
    form.lines
  end

  def line_rows(ids)
    rows = ids.map { |id| row_for(players.fetch(id.to_i)) }
    rows.fill(EMPTY_ROW, rows.size...SEATS)
  end

  def row_for(player)
    Row.build(player, ratings.for(player.id), sub: roster.exclude?(player),
                                              status: statuses[player.id],
                                              preferences: preferences.fetch(player.id, {}))
  end

  def statuses
    @statuses ||= @match.match_night.match_availabilities.where(player: roster + form.eligible_subs)
                        .to_h { |row| [row.player_id, row.status] }
  end

  def preferences
    @preferences ||= preference_rows.transform_values { |list| list.to_h { |row| [row.match_slot_id, row.preference] } }
  end

  def preference_rows
    SlotAvailability.where(match_slot: slots, player: roster + form.eligible_subs).group_by(&:player_id)
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

  attr_reader :ratings
end
