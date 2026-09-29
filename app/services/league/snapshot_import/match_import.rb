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
        Array(json_match['lines']).each { |line| import_line(line) }
      end

      private

      def import_line(line)
        home_names, away_names = line_players(line)
        return warn_short_line(line) if home_names.size < 2 || away_names.size < 2
        return unless resolvable?(line, home_names, away_names)
        return unless valid_position?(line)

        create_lineup(line, home_names, away_names)
      end

      def line_players(line)
        [Array(line['a']).compact_blank, Array(line['b']).compact_blank]
      end

      def valid_position?(line)
        position = line['line']
        return true if position.is_a?(Integer) && match.lineups.where(position: position).none?

        report.warn("Match #{json_match['id']} line #{position.inspect}: invalid or duplicate line number, skipped.")
        false
      end

      def create_lineup(line, home_names, away_names)
        lineup = match.lineups.create!(position: line['line'])
        import_games(lineup, home_names, away_names, line['scores'])
        finalize_lineup(lineup)
      end

      def finalize_lineup(lineup)
        if lineup.games.reload.empty?
          lineup.destroy!
        else
          report.increment_lineups
        end
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
        Array(scores).first(Lineup::GAMES_PER_LINEUP).each_with_index do |raw_pair, index|
          next unless (pair = playable_pair(raw_pair, index))

          import_game(lineup, home_names, away_names, index, pair)
        end
      end

      def playable_pair(raw_pair, index)
        pair = Array(raw_pair)
        return nil if unplayed?(pair)
        return warn_malformed_pair(pair, index) unless pair.size == 2 && pair.all?(Integer)

        pair
      end

      def unplayed?(pair)
        pair.size == 2 && (pair[0].nil? || pair[1].nil? || pair == [0, 0])
      end

      def warn_malformed_pair(pair, index)
        report.warn("Match #{json_match['id']} game #{index + 1}: malformed score #{pair.inspect}, skipped.")
        nil
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
        return report.increment_games if game.save
        return warn_invalid_game(game) unless only_final_score_error?(game)

        force_save_game(game)
        report.increment_games
      end

      def force_save_game(game)
        report.warn("Match #{json_match['id']} game #{game.home_score}-#{game.away_score}: " \
                    "#{game.errors.full_messages.join(', ')}. Imported anyway.")
        game.save!(validate: false)
      end

      def warn_invalid_game(game)
        errors = game.errors.full_messages.join(', ')
        report.warn("Match #{json_match['id']} game #{game.number}: #{errors}, skipped.")
      end

      def only_final_score_error?(game)
        game.errors.full_messages == ["must be played to #{Game::WINNING_SCORE}, win by #{Game::WIN_BY}"]
      end
    end
  end
end
