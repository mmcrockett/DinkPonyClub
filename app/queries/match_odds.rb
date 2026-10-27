# frozen_string_literal: true

class MatchOdds
  MIN_PLAYERS = 2
  VIG = 0.05

  def initialize(lines:, sweep_bonus:)
    @lines = lines.select { |_position, sides| sides.all? { |elos| elos.size >= MIN_PLAYERS } }
    @bonus = sweep_bonus.to_f
  end

  def playable?
    @lines.any?
  end

  def win_probability
    return unless playable?

    @win_probability ||= spread.sum { |diff, chance| chance * (diff <=> 0).then { |sign| (sign + 1) / 2.0 } }
  end

  def moneylines
    return unless playable?

    { mine: moneyline(win_probability), theirs: moneyline(1 - win_probability) }
  end

  def line_moneylines
    @lines.transform_values do |(ours, theirs)|
      chance = win_counts(game_probabilities(ours, theirs)).last(2).sum
      { mine: moneyline(chance), theirs: moneyline(1 - chance) }
    end
  end

  private

  def spread
    line_spreads = @lines.values.map { |ours, theirs| line_spread(ours, theirs) }
    line_spreads.reduce({ 0.0 => 1.0 }) { |total, line| combine(total, line) }
  end

  def combine(total, line)
    total.each_with_object(Hash.new(0.0)) do |(a, chance_a), sums|
      line.each { |b, chance_b| sums[(a + b).round(4)] += chance_a * chance_b }
    end
  end

  def line_spread(ours, theirs)
    win_counts(game_probabilities(ours, theirs)).each_with_index.to_h { |chance, wins| [points_diff(wins), chance] }
  end

  def game_probabilities(ours, theirs)
    Array.new(Lineup::GAMES_PER_LINEUP) do |index|
      gap = average(Game.pair_for(theirs, index)) - average(Game.pair_for(ours, index))
      1 / (1 + (10**(gap / 400.0)))
    end
  end

  def win_counts(probabilities)
    probabilities.reduce([1.0]) do |counts, chance|
      Array.new(counts.size + 1) do |wins|
        ((counts[wins] || 0.0) * (1 - chance)) + (wins.positive? ? counts[wins - 1] * chance : 0.0)
      end
    end
  end

  def points_diff(wins)
    games = Lineup::GAMES_PER_LINEUP
    ours = wins + (wins == games ? @bonus : 0)
    theirs = (games - wins) + (wins.zero? ? @bonus : 0)
    ours - theirs
  end

  def average(elos)
    elos.sum / elos.size.to_f
  end

  def moneyline(chance)
    implied = (chance * (1 + VIG)).clamp(0.01, 0.99)

    return "+#{((100 * (1 - implied) / implied) / 5).ceil * 5}" if implied < 0.5

    favorite = ((100 * implied / (1 - implied)) / 5).floor * 5
    favorite > 100 ? "-#{favorite}" : 'EVEN'
  end
end
