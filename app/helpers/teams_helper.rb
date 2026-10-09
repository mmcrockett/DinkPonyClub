# frozen_string_literal: true

module TeamsHelper
  MatchLine = Struct.new(:match, :opponent, :home, :score, :outcome, keyword_init: true)

  def team_link(team, season)
    link_to team.name, season_team_path(season, team), class: 'hover:underline'
  end

  def standings_team_link(team, season)
    return team.name if lifetime_period? && !season.teams.exists?(team.id)

    team_link(team, season)
  end

  def team_logo(team, **)
    path = "team-logos/#{team.name.parameterize}.webp"
    image_tag(path, alt: '', **) if Rails.application.assets.load_path.find(path)
  end

  def team_match_line(team, match)
    home = match.home_team == team
    result = MatchResult.new(match)

    MatchLine.new(match: match, opponent: home ? match.away_team : match.home_team, home: home,
                  score: (team_score_label(result, home) if match.complete?),
                  outcome: (result.outcome_for(team) if match.complete?))
  end

  private

  def team_score_label(result, home)
    own, other = home ? [result.home_points, result.away_points] : [result.away_points, result.home_points]
    "#{format_points(own)} - #{format_points(other)}"
  end
end
