# frozen_string_literal: true

class ScorecardForm
  class Line
    include ActiveModel::Model

    ROTATION = [[0, 1], [0, 2], [1, 2]].freeze
    SCORE_FORMAT = /\A\d{1,2}\z/

    attr_reader :form, :position, :home_player_ids, :away_player_ids, :scores

    def initialize(form, position, attrs = {})
      @form = form
      @position = position
      @home_player_ids = clean_ids(attrs[:home_player_ids] || attrs['home_player_ids'])
      @away_player_ids = clean_ids(attrs[:away_player_ids] || attrs['away_player_ids'])
      @scores = build_scores(attrs)
    end

    validate :enough_players
    validate :no_duplicate_players_on_a_side
    validate :no_overlap_between_sides
    validate :scores_are_valid

    def all_player_ids
      home_player_ids + away_player_ids
    end

    def persist!
      lineup = form.match.lineups.create!(position: position)
      scores.each_with_index { |pair, index| persist_game!(lineup, pair, index) }
    end

    def persist_picks!
      rows = pick_rows(form.match.home_team_id, home_player_ids) + pick_rows(form.match.away_team_id, away_player_ids)
      LineupPick.insert_all!(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
    end

    def game_player_ids(side, game_index)
      rotate(side == :home ? home_player_ids : away_player_ids, game_index)
    end

    private

    def pick_rows(team_id, ids)
      now = Time.current
      ids.each_with_index.map do |id, index|
        { match_id: form.match.id, team_id: team_id, player_id: id, position: position, seat: index + 1,
          created_at: now, updated_at: now }
      end
    end

    def persist_game!(lineup, pair, index)
      home_score, away_score = pair
      return unless home_score.present? && away_score.present?

      lineup.games.create!(game_attrs(index, home_score, away_score,
                                      game_player_ids(:home, index), game_player_ids(:away, index)))
    end

    def game_attrs(index, home_score, away_score, home_pair, away_pair)
      { number: index + 1, home_score: home_score, away_score: away_score,
        home_player_a_id: home_pair[0], home_player_b_id: home_pair[1],
        away_player_a_id: away_pair[0], away_player_b_id: away_pair[1] }
    end

    def clean_ids(ids)
      Array(ids).map(&:to_s).compact_blank.first(3)
    end

    def build_scores(attrs)
      (1..Lineup::GAMES_PER_LINEUP).map { |number| [score(attrs, :home_score, number), score(attrs, :away_score, number)] }
    end

    def score(attrs, prefix, number)
      key = :"#{prefix}#{number}"
      (attrs[key] || attrs[key.to_s]).presence
    end

    def rotate(ids, game_index)
      ids.size == 2 ? ids : ROTATION[game_index].map { |i| ids[i] }
    end

    def enough_players
      errors.add(:base, 'home side needs at least two players') if home_player_ids.size < 2
      errors.add(:base, 'away side needs at least two players') if away_player_ids.size < 2
    end

    def no_duplicate_players_on_a_side
      errors.add(:base, 'a player cannot appear twice on the home side') if duplicates?(home_player_ids)
      errors.add(:base, 'a player cannot appear twice on the away side') if duplicates?(away_player_ids)
    end

    def duplicates?(ids)
      ids.uniq.size != ids.size
    end

    def no_overlap_between_sides
      return unless home_player_ids.intersect?(away_player_ids)

      errors.add(:base, 'a player cannot play both sides of a line')
    end

    def scores_are_valid
      scores.each_with_index do |pair, index|
        message = score_pair_error(pair)
        errors.add(:base, "game #{index + 1} #{message}") if message
      end
    end

    def score_pair_error(pair)
      home, away = pair
      return nil if home.blank? && away.blank?
      return 'needs both scores' if home.blank? || away.blank?

      format_or_tie_error(home, away)
    end

    def format_or_tie_error(home, away)
      return 'scores must be numbers between 0 and 99' unless valid_score?(home) && valid_score?(away)
      return 'cannot end in a tie' if home.to_i == away.to_i

      nil
    end

    def valid_score?(value)
      value.to_s.match?(SCORE_FORMAT)
    end
  end
end
