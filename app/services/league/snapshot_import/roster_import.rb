# frozen_string_literal: true

module League
  class SnapshotImport
    class RosterImport
      attr_reader :season, :teams, :report

      def initialize(season, teams, report)
        @season = season
        @teams = teams
        @report = report
      end

      def import(people)
        resolver = PlayerResolver.new(report)
        people.to_h do |person|
          player = resolver.resolve(person)
          import_roster_spot(person, player)
          [person['name'], player]
        end
      end

      private

      def import_roster_spot(person, player)
        if person['team'] == 'SUBS'
          report.warn("#{player.full_name} has no team (SUBS); imported as a player only.")
          return
        end

        team = teams.fetch(person['team']) { raise Error, "Unknown team #{person['team']} for #{player.full_name}." }
        save_roster_spot(team, person, player)
      end

      def save_roster_spot(team, person, player)
        spot = RosterSpot.find_or_initialize_by(season: season, player: player)
        spot.team = team
        spot.draft_rank = person['rank'].presence
        spot.captain = true if person['captain'] == true
        spot.save!
        report.increment_roster_spots
        report.roster_line(team.name, player, spot)
      end
    end
  end
end
