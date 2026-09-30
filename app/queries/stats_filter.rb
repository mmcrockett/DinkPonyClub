# frozen_string_literal: true

class StatsFilter
  SORTS = %w[name win_pct_desc win_pct_asc team].freeze
  SUBSTITUTES = 'substitutes'

  attr_reader :query, :team, :sort

  def initialize(rows, params = {})
    @all_rows = rows
    @query = params[:q].to_s.strip
    @team = params[:team].presence
    @hide_substitutes = params[:hide_substitutes] == '1'
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : SORTS.first
  end

  def hide_substitutes?
    @hide_substitutes
  end

  def rows
    sorted(@all_rows.select { |row| matches_query?(row) && matches_team?(row) && shown?(row) })
  end

  private

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
    rows.sort_by { |row| sort_key(row) }
  end

  def sort_key(row)
    case sort
    when 'win_pct_desc' then [*win_pct_key(row, -1), name_key(row)]
    when 'win_pct_asc' then [*win_pct_key(row, 1), name_key(row)]
    when 'team' then [*team_key(row), name_key(row)]
    else [name_key(row)]
    end
  end

  def win_pct_key(row, direction)
    row.win_pct ? [0, direction * row.win_pct] : [1, 0]
  end

  def team_key(row)
    row.substitute? ? [1, ''] : [0, row.team.name.downcase]
  end

  def name_key(row)
    row.player.full_name.downcase
  end
end
