# frozen_string_literal: true

module League
  class PlayoffBracket
    class Error < StandardError; end

    TEAMS = 4

    def initialize(match_night)
      @match_night = match_night
      @season = match_night.season
    end

    def seed!
      raise Error, 'Playoff night required' unless @match_night.playoff?
      raise Error, 'Night already has matches' if @match_night.matches.exists?

      seeds = seeded_teams
      Match.transaction do
        create_match(seeds[0], seeds[3], :semifinal)
        create_match(seeds[1], seeds[2], :semifinal)
      end
    end

    def create_final!
      bracket = ::PlayoffBracket.new(@match_night)
      raise Error, 'Both semifinals must be complete' unless bracket.ready_for_final?

      semifinals = bracket.semifinals
      final = create_match(*semifinals.map { |semifinal| bracket.advancing(semifinal) }, :final)
      semifinals.each { |semifinal| copy_picks(semifinal, final) }
      final
    end

    private

    def seeded_teams
      teams = Standings.new(@season).rows.map(&:team)
      raise Error, "Seeding needs exactly #{TEAMS} teams" unless teams.size == TEAMS

      teams
    end

    def copy_picks(semifinal, final)
      team = ::PlayoffBracket.new(@match_night).advancing(semifinal)
      semifinal.lineup_picks.where(team: team).find_each do |pick|
        final.lineup_picks.create!(team: team, player_id: pick.player_id, position: pick.position, seat: pick.seat)
      end
    end

    def create_match(home, away, round)
      @match_night.matches.create!(season: @season, home_team: home, away_team: away, round: round)
    end
  end
end
