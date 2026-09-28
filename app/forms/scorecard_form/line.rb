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
    validate :no_overlap_between_sides
    validate :players_are_rostered
    validate :scores_are_valid

    def all_player_ids
      home_player_ids + away_player_ids
    end

    def persist!
      lineup = form.match.lineups.create!(position: position)
      scores.each_with_index { |pair, index| persist_game!(lineup, pair, index) }
    end

    private

    def persist_game!(lineup, pair, index)
      home_score, away_score = pair
      return unless home_score.present? && away_score.present?

      home_pair = rotate(home_player_ids, index)
      away_pair = rotate(away_player_ids, index)
      lineup.games.create!(game_attrs(index, home_score, away_score, home_pair, away_pair))
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

    def no_overlap_between_sides
      return unless home_player_ids.intersect?(away_player_ids)

      errors.add(:base, 'a player cannot play both sides of a line')
    end

    def players_are_rostered
      match = form.match
      return unless match.home_team && match.away_team && match.season

      check_side('home', home_player_ids, match.home_team.roster_for(match.season))
      check_side('away', away_player_ids, match.away_team.roster_for(match.season))
    end

    def check_side(label, ids, roster)
      return if ids.empty?

      roster_ids = roster.pluck(:id).map(&:to_s)
      return if ids.all? { |id| roster_ids.include?(id) }

      errors.add(:base, "#{label} players must be on the #{label} team roster for this season")
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
