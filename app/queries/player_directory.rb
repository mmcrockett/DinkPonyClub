# frozen_string_literal: true

class PlayerDirectory
  SUBSTITUTES = 'substitutes'
  SORT_KEYS = {
    'win_pct' => ->(row) { [row.win_pct ? -row.win_pct : 1] },
    'team' => ->(row) { [row.substitute? ? 1 : 0, row.team&.name.to_s] }
  }.freeze
  NO_SORT_KEY = ->(_row) { [] }

  def initialize(rows, query: nil, team: nil, hide_substitutes: false, sort: nil)
    @all_rows = rows
    @query = query.to_s.strip.downcase
    @team = team.presence
    @hide_substitutes = hide_substitutes
    @sort_key = SORT_KEYS.fetch(sort, NO_SORT_KEY)
  end

  def rows
    @all_rows.select { |row| visible?(row) }.sort_by { |row| @sort_key.call(row) + name_key(row) }
  end

  private

  def visible?(row)
    return false if @hide_substitutes && row.substitute?

    matches_query?(row) && matches_team?(row)
  end

  def matches_query?(row)
    @query.empty? || row.player.full_name.downcase.include?(@query)
  end

  def matches_team?(row)
    case @team
    when nil then true
    when SUBSTITUTES then row.substitute?
    else row.team&.id.to_s == @team
    end
  end

  def name_key(row)
    [row.player.first_name.downcase, row.player.last_name.downcase]
  end
end
