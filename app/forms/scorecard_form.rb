# frozen_string_literal: true

class ScorecardForm
  include ActiveModel::Model

  attr_reader :match, :lines

  class << self
    def from_match(match)
      lines_attrs = attrs_from_picks(match)
      match.lineups.includes(:games).find_each do |lineup|
        picked = lines_attrs.fetch(lineup.position, {})
        lines_attrs[lineup.position] = picked.merge(attrs_from_lineup(lineup)) { |_key, old, new| new.presence || old }
      end
      new(match: match, lines: lines_attrs)
    end

    private

    def attrs_from_picks(match)
      picks = match.lineup_picks.ordered.group_by { |pick| [pick.team_id, pick.position] }
      match.line_positions.index_with do |position|
        { home_player_ids: pick_ids(picks, match.home_team_id, position),
          away_player_ids: pick_ids(picks, match.away_team_id, position) }
      end
    end

    def pick_ids(picks, team_id, position)
      picks.fetch([team_id, position], []).map { |pick| pick.player_id.to_s }
    end

    def attrs_from_lineup(lineup)
      games = lineup.games.to_a
      attrs = { home_player_ids: extract_ids(games, :home), away_player_ids: extract_ids(games, :away) }
      games.each do |game|
        attrs[:"home_score#{game.number}"] = game.home_score
        attrs[:"away_score#{game.number}"] = game.away_score
      end
      attrs
    end

    def extract_ids(games, side)
      a_method = :"#{side}_player_a_id"
      b_method = :"#{side}_player_b_id"
      ids = []
      games.sort_by(&:number).each do |game|
        [game.public_send(a_method), game.public_send(b_method)].each { |id| ids << id unless ids.include?(id) }
      end
      ids.map(&:to_s)
    end
  end

  def initialize(match:, lines: {})
    @match = match
    @lines = match.line_positions.map do |position|
      Line.new(self, position, lines[position] || lines[position.to_s] || {})
    end
  end

  validate :lines_are_valid
  validate :players_appear_on_one_line_only

  def fingerprint
    rows = match.games.reload.order(:id).pluck(:id, :number, :home_score, :away_score, :updated_at)
    Digest::SHA1.hexdigest([match.lineups.reload.pluck(:id).sort, rows].to_json)
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      match.lineups.destroy_all
      match.reload
      lines.each(&:persist!)
      sync_picks!
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  def lineup_ready?
    lines.all? { |line| line.home_player_ids.size >= 2 && line.away_player_ids.size >= 2 }
  end

  private

  def sync_picks!
    match.lineup_picks.destroy_all
    lines.each do |line|
      create_picks!(match.home_team, line, line.home_player_ids)
      create_picks!(match.away_team, line, line.away_player_ids)
    end
  end

  def create_picks!(team, line, ids)
    ids.each_with_index do |id, index|
      match.lineup_picks.create!(team: team, player_id: id, position: line.position, seat: index + 1)
    end
  end

  def lines_are_valid
    lines.each do |line|
      next if line.valid?

      line.errors.full_messages.each { |message| errors.add(:base, "Line #{line.position}: #{message}") }
    end
  end

  def players_appear_on_one_line_only
    seen = {}
    lines.each do |line|
      line.all_player_ids.uniq.each do |id|
        if seen[id]
          errors.add(:base, "Line #{seen[id]} and Line #{line.position}: a player cannot appear on two lines")
        else
          seen[id] = line.position
        end
      end
    end
  end
end
