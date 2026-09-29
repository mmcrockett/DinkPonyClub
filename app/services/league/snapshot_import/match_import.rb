# frozen_string_literal: true

module League
  class SnapshotImport
    class MatchImport
      ROTATION = [[0, 1], [0, 2], [1, 2]].freeze

      attr_reader :match, :json_match, :players, :report

      def initialize(match, json_match, players, report)
        @match = match
        @json_match = json_match
        @players = players
        @report = report
      end

      def call
        json_match['lines'].each { |line| import_line(line) }
      end

      private

      def import_line(line)
        home_names, away_names = line_players(line)
        return warn_short_line(line) if home_names.size < 2 || away_names.size < 2
        return unless resolvable?(line, home_names, away_names)

        create_lineup(line, home_names, away_names)
      end

      def line_players(line)
        [Array(line['a']).compact_blank, Array(line['b']).compact_blank]
      end

      def create_lineup(line, home_names, away_names)
        lineup = match.lineups.create!(position: line['line'])
        report.increment_lineups
        import_games(lineup, home_names, away_names, line['scores'])
      end

      def resolvable?(line, home_names, away_names)
        missing = (home_names + away_names).reject { |name| players.key?(name) }
        return true if missing.empty?

        report.warn("Match #{json_match['id']} line #{line['line']}: unknown player(s) #{missing.join(', ')}, skipped.")
        false
      end

      def warn_short_line(line)
        report.warn("Match #{json_match['id']} line #{line['line']}: fewer than 2 players on a side, skipped.")
      end

      def import_games(lineup, home_names, away_names, scores)
        Array(scores).first(Lineup::GAMES_PER_LINEUP).each_with_index do |pair, index|
          next if pair[0].nil? || pair[1].nil? || (pair[0].zero? && pair[1].zero?)

          import_game(lineup, home_names, away_names, index, pair)
        end
      end

      def import_game(lineup, home_names, away_names, index, pair)
        home_a, home_b = pair_for(home_names, index)
        away_a, away_b = pair_for(away_names, index)
        game = lineup.games.new(number: index + 1, home_score: pair[0], away_score: pair[1],
                                home_player_a: players[home_a], home_player_b: players[home_b],
                                away_player_a: players[away_a], away_player_b: players[away_b])
        persist_game(game)
      end

      def pair_for(names, index)
        slots = names.size >= 3 ? ROTATION[index] : ROTATION[0]
        slots.map { |slot| names[slot] }
      end

      def persist_game(game)
        unless game.save
          report.warn("Match #{json_match['id']} game #{game.home_score}-#{game.away_score}: " \
                      "#{game.errors.full_messages.join(', ')}. Imported anyway.")
          game.save!(validate: false)
        end
        report.increment_games
      end
    end
  end
end
