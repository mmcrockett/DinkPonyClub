# frozen_string_literal: true

class CourtSchedule
  Cell = Data.define(:match, :position, :home_players, :away_players)
  Conflict = Data.define(:kind, :player, :slot)

  delegate :any?, to: :assignments

  def initialize(match_night)
    @match_night = match_night
  end

  def rows
    @rows ||= slots.map { |slot| [slot, CourtAssignment::COURTS.index_with { |court| cells[[slot.id, court]] }] }
  end

  def unplaced
    placed = assignments.map { |assignment| [assignment.match_id, assignment.position] }
    lines.reject { |match, position| placed.include?([match.id, position]) }
  end

  def lines
    @lines ||= matches.flat_map { |match| match.line_positions.map { |position| [match, position] } }
  end

  def selected(slot, court)
    cell = cells[[slot.id, court]]
    "#{cell.match.id}-#{cell.position}" if cell
  end

  def conflicts
    @conflicts ||= players_by_slot.flat_map { |slot, players| conflicts_in(slot, players) }
  end

  def flagged?(slot, player)
    conflicts.any? { |conflict| conflict.slot == slot && conflict.player == player }
  end

  private

  def slots
    @slots ||= @match_night.match_slots.to_a
  end

  def matches
    @matches ||= @match_night.matches.includes(:home_team, :away_team, lineup_picks: :player).order(:id).to_a
  end

  def assignments
    @assignments ||= @match_night.court_assignments.to_a
  end

  def cells
    @cells ||= assignments.to_h do |assignment|
      match = matches.find { |candidate| candidate.id == assignment.match_id }
      [[assignment.match_slot_id, assignment.court], cell_for(match, assignment.position)]
    end
  end

  def cell_for(match, position)
    Cell.new(match: match, position: position,
             home_players: players_for(match, match.home_team_id, position),
             away_players: players_for(match, match.away_team_id, position))
  end

  def players_for(match, team_id, position)
    match.lineup_picks.select { |pick| pick.team_id == team_id && pick.position == position }
         .sort_by(&:seat).map(&:player)
  end

  def players_by_slot
    slots_by_id = slots.index_by(&:id)
    grouped = cells.group_by { |(slot_id, _court), _cell| slots_by_id[slot_id] }
    grouped.transform_values { |entries| entries.flat_map { |_key, cell| cell.home_players + cell.away_players } }
  end

  def conflicts_in(slot, players)
    declined = players.uniq.select { |player| declined_slots.include?([slot.id, player.id]) }
    doubled = players.group_by(&:id).values.select { |group| group.size > 1 }.map(&:first)
    conflicts_of(:declined, declined, slot) + conflicts_of(:double_booked, doubled, slot)
  end

  def conflicts_of(kind, players, slot)
    players.map { |player| Conflict.new(kind: kind, player: player, slot: slot) }
  end

  def declined_slots
    @declined_slots ||= SlotAvailability.thumbs_down.where(match_slot_id: slots.map(&:id))
                                        .pluck(:match_slot_id, :player_id)
  end
end
