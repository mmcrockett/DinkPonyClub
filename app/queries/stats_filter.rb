# frozen_string_literal: true

class StatsFilter
  SORTS = %w[name team games wins losses win_pct].freeze
  RATING = 'rating'
  DESCENDING_BY_DEFAULT = %w[games wins losses win_pct rating].freeze
  DIRECTIONS = %w[asc desc].freeze
  SUBSTITUTES = 'substitutes'

  attr_reader :query, :team, :sort, :direction

  def self.default_direction(sort)
    DESCENDING_BY_DEFAULT.include?(sort) ? 'desc' : 'asc'
  end

  def initialize(rows, params = {})
    @all_rows = rows
    @ratings = rows.any?(&:rating)
    @query = params[:q].to_s.strip
    @team = params[:team].presence
    @hide_substitutes = params[:hide_substitutes] == '1'
    @sort = sorts.include?(params[:sort]) ? params[:sort] : SORTS.first
    @direction = direction_from(params[:dir])
  end

  def sorts
    @ratings ? SORTS + [RATING] : SORTS
  end

  def ratings?
    @ratings
  end

  def hide_substitutes?
    @hide_substitutes
  end

  def descending?
    direction == 'desc'
  end

  def next_direction(column)
    return self.class.default_direction(column) unless column == sort

    descending? ? 'asc' : 'desc'
  end

  def rows
    sorted(@all_rows.select { |row| matches_query?(row) && matches_team?(row) && shown?(row) })
  end

  private

  def direction_from(value)
    DIRECTIONS.include?(value) ? value : self.class.default_direction(sort)
  end

  def matches_query?(row)
    query.empty? || row.player.full_name.downcase.include?(query.downcase)
  end

  def matches_team?(row)
    return true if team.nil?
    return row.substitute? if team == SUBSTITUTES

    row.team&.id.to_s == team
  end

  def shown?(row)
    !(hide_substitutes? && row.substitute?)
  end

  def sorted(rows)
    valued, unvalued = rows.partition { |row| sort_value(row) }

    valued.sort { |a, b| compare(a, b) } + unvalued.sort_by { |row| name_key(row) }
  end

  def compare(first, second)
    by_value = sort_value(first) <=> sort_value(second)
    (descending? ? -by_value : by_value).nonzero? || (name_key(first) <=> name_key(second))
  end

  def sort_value(row)
    case sort
    when 'team' then row.team&.name&.downcase
    when 'games', 'wins', 'losses', 'win_pct', RATING then row.public_send(sort)
    else name_key(row)
    end
  end

  def name_key(row)
    row.player.full_name.downcase
  end
end
