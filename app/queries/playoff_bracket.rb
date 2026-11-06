# frozen_string_literal: true

class PlayoffBracket
  attr_reader :match_night

  def initialize(match_night)
    @match_night = match_night
  end

  delegate :any?, to: :rounds

  def semifinals
    rounds.select(&:semifinal?).sort_by(&:id)
  end

  def final
    rounds.find(&:final?)
  end

  def advancing(match)
    return unless match&.complete?

    MatchResult.new(match).winner || match.home_team
  end

  def ready_for_final?
    final.nil? && semifinals.size == 2 && semifinals.all?(&:complete?)
  end

  def champion
    advancing(final)
  end

  private

  def rounds
    @rounds ||= match_night.matches.select(&:round)
  end
end
