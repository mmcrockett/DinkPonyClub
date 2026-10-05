# frozen_string_literal: true

class LineupPlanForm
  include ActiveModel::Model

  attr_reader :match, :team, :lines

  def self.from_match(match, team)
    picks = match.lineup_picks.where(team: team).ordered.group_by(&:position)
    lines = picks.transform_values { |rows| rows.map { |row| row.player_id.to_s } }
    new(match: match, team: team, lines: lines)
  end

  def initialize(match:, team:, lines: {})
    @match = match
    @team = team
    @lines = ScorecardForm::POSITIONS.index_with { |position| clean_ids(lines[position] || lines[position.to_s]) }
  end

  validate :lines_have_enough_players
  validate :players_are_on_roster
  validate :players_appear_once

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      match.lineup_picks.where(team: team).delete_all
      lines.each { |position, ids| create_picks(position, ids) }
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  def roster
    @roster ||= team.roster_for(match.season).to_a
  end

  private

  def create_picks(position, ids)
    ids.each_with_index do |id, index|
      match.lineup_picks.create!(team: team, player_id: id, position: position, seat: index + 1)
    end
  end

  def clean_ids(ids)
    Array(ids).map(&:to_s).compact_blank.first(LineupPick::SEATS.size)
  end

  def lines_have_enough_players
    lines.each do |position, ids|
      errors.add(:base, "Line #{position}: needs at least two players") if ids.size == 1
    end
  end

  def players_are_on_roster
    unknown = lines.values.flatten - roster.map { |player| player.id.to_s }
    errors.add(:base, "That player isn't on this season's roster.") if unknown.any?
  end

  def players_appear_once
    ids = lines.values.flatten
    errors.add(:base, 'A player cannot appear twice in the lineup') if ids.uniq.size != ids.size
  end
end
