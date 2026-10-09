# frozen_string_literal: true

class PlayerRatings
  module Seeding
    private

    def seed(tier, count)
      BASE + (LINE_STEP * (((count + 1) / 2.0) - tier.clamp(1, count)))
    end

    def tier_from_rank(rank)
      text = rank.to_s.strip.upcase
      return text.to_i if text.match?(/\A[1-9]/)

      text.ord - 'A'.ord + 1 if text.match?(/\A[A-E]/)
    end

    def line_count(season_id)
      line_counts[season_id] || DEFAULT_LINES
    end

    def line_counts
      @line_counts ||= Lineup.joins(:match).group('matches.season_id').maximum(:position)
    end

    def draft_ranks
      @draft_ranks ||= RosterSpot.pluck(:season_id, :player_id, :draft_rank)
                                 .to_h { |season_id, player_id, rank| [[season_id, player_id], rank] }
    end
  end
end
