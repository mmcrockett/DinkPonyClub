# frozen_string_literal: true

module League
  class SnapshotImport
    class Report
      COUNTERS = %i[seasons_created seasons_matched teams_created teams_matched players_created players_matched
                    roster_spots match_nights matches lineups games availabilities].freeze

      attr_reader :warnings, :roster

      def initialize
        @counts = Hash.new(0)
        @warnings = []
        @roster = Hash.new { |hash, team_name| hash[team_name] = [] }
      end

      COUNTERS.each do |counter|
        define_method("increment_#{counter}") { @counts[counter] += 1 }
      end

      def count(counter)
        @counts[counter]
      end

      def warn(message)
        @warnings << message
      end

      def roster_line(team_name, player, roster_spot)
        tag = roster_spot.captain? ? ' (captain)' : ''
        rank = roster_spot.draft_rank.presence && " [#{roster_spot.draft_rank}]"
        @roster[team_name] << "#{player.full_name}#{tag}#{rank}"
      end

      def to_s
        [counts_block, roster_block, captain_note, warnings_block].compact.join("\n\n")
      end

      private

      def counts_block
        COUNTERS.map { |counter| "#{counter.to_s.tr('_', ' ').capitalize}: #{@counts[counter]}" }.join("\n")
      end

      def roster_block
        @roster.map { |team_name, players| "#{team_name}:\n  #{players.join("\n  ")}" }.join("\n")
      end

      def captain_note
        'Set any remaining captains via Admin > Players or ' \
          '`RosterSpot.find_by(...).update!(captain: true)`.'
      end

      def warnings_block
        return 'Warnings: none' if warnings.empty?

        "Warnings:\n#{warnings.each_with_index.map { |message, index| "  #{index + 1}. #{message}" }.join("\n")}"
      end
    end
  end
end
