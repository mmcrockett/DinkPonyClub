# frozen_string_literal: true

module StatsHelper
  def stats_win_pct(row)
    return '-' if row.win_pct.nil?

    number_to_percentage(row.win_pct * 100, precision: 0)
  end

  def stats_team_name(row)
    row.substitute? ? t('stats.show.substitute') : row.team.name
  end
end
