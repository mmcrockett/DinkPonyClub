# frozen_string_literal: true

module NavigationHelper
  def sidebar_items
    items = [
      { label: 'Home', icon: 'home', path: root_path },
      { label: 'Seasons', icon: 'layers', path: seasons_path },
      { label: 'Teams', icon: 'users', path: (season_teams_path(nav_season) if nav_season) },
      { label: 'Schedule', icon: 'calendar', path: season_nav_path(:match_nights) },
      { label: 'Players', icon: 'user', path: season_nav_path(:players) },
      { label: 'Standings', icon: 'trophy', path: season_nav_path(:standings) },
      { label: 'Rules & Format', icon: 'book-open', path: rules_path }
    ]
    items << { label: 'Admin', icon: 'cog', path: admin_players_path } if admin?
    items
  end

  def app_version
    ENV['APP_VERSION'].presence
  end

  def app_revision
    ENV['KAMAL_VERSION'].to_s.first(7).presence
  end

  def sidebar_expanded?
    cookies[:sidebar] != 'collapsed'
  end

  private

  def season_nav_path(resource)
    return public_send("#{resource}_path") unless nav_season

    public_send("season_#{resource}_path", nav_season)
  end
end
