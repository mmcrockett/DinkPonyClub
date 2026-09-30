# frozen_string_literal: true

module NavigationHelper
  def sidebar_items
    items = [
      { label: 'Home', icon: 'home', path: root_path },
      { label: 'Seasons', icon: 'layers', path: seasons_path },
      { label: 'Teams', icon: 'users' },
      { label: 'Schedule', icon: 'calendar', path: match_nights_path },
      { label: 'Players', icon: 'user', path: players_path },
      { label: 'Standings', icon: 'trophy', path: standings_path },
      { label: 'Stats', icon: 'chart', path: stats_path }
    ]
    items << { label: 'Admin', icon: 'cog', path: admin_players_path } if admin?
    items
  end

  def sidebar_expanded?
    cookies[:sidebar] != 'collapsed'
  end
end
