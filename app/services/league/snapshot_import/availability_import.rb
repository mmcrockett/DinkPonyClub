# frozen_string_literal: true

module League
  class SnapshotImport
    class AvailabilityImport
      STATUS_MAP = { 'yes' => 'in', 'no' => 'out', 'maybe' => 'maybe' }.freeze

      attr_reader :match_nights, :players, :report

      def initialize(match_nights, players, report)
        @match_nights = match_nights
        @players = players
        @report = report
      end

      def import(people)
        people.each { |person| import_player_availability(person) }
      end

      private

      def import_player_availability(person)
        player = players.fetch(person['name'])
        Array(person['availability']).sort_by { |week_id, _status| week_id.to_i }.each do |week_id, status|
          import_entry(player, week_id, status)
        end
      end

      def import_entry(player, week_id, status)
        mapped = STATUS_MAP[status]
        return if status == 'unknown'
        return report.warn("Unrecognized availability status \"#{status}\" for #{player.full_name}.") unless mapped

        night = match_nights[week_id.to_i]
        return report.warn("#{player.full_name}: unknown week #{week_id}, availability skipped.") unless night

        save_availability(night, player, mapped)
      end

      def save_availability(night, player, mapped)
        availability = MatchAvailability.find_or_initialize_by(match_night: night, player: player)
        availability.status = mapped
        availability.save!
        report.increment_availabilities if availability.previously_new_record?
      end
    end
  end
end
