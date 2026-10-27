require 'test_helper'

class MatchOddsTest < ActiveSupport::TestCase
  test 'evenly matched teams both pay the vig at -110' do
    odds = MatchOdds.new(lines: lines_of(3, [1500, 1500], [1500, 1500]), sweep_bonus: 0.5)

    assert_in_delta 0.5, odds.win_probability, 0.001
    assert_equal({ mine: '-110', theirs: '-110' }, odds.moneylines)
  end

  test 'the stronger side is the negative favorite' do
    odds = MatchOdds.new(lines: lines_of(2, [1600, 1600], [1500, 1500]), sweep_bonus: 0.5)

    assert_operator odds.win_probability, :>, 0.5
    assert_match(/\A-\d+\z/, odds.moneylines[:mine])
    assert_match(/\A\+\d+\z/, odds.moneylines[:theirs])
  end

  test 'rounding never widens the vig beyond the nominal hold' do
    (0..40).step(3) do |gap|
      lines = lines_of(3, [1500 + gap] * 2, [1500, 1500])
      lines_text = MatchOdds.new(lines: lines, sweep_bonus: 0.5).moneylines.values_at(:mine, :theirs)

      assert_operator lines_text.sum { |text| implied(text) }, :<=, 1.0501, "gap #{gap}"
    end
  end

  test 'a short line is skipped and no playable lines gives no odds' do
    short = MatchOdds.new(lines: lines_of(1, [1500], [1500, 1500]), sweep_bonus: 0.5)

    assert_not short.playable?
    assert_nil short.moneylines
  end

  test 'the sweep bonus shifts the odds toward the favorite' do
    lines = lines_of(1, [1600, 1600], [1500, 1500])
    without = MatchOdds.new(lines: lines, sweep_bonus: 0).win_probability
    with = MatchOdds.new(lines: lines, sweep_bonus: 0.5).win_probability

    assert_operator with, :>=, without
  end

  test 'each playable line gets its own money lines' do
    odds = MatchOdds.new(lines: { 1 => [[1600, 1600], [1500, 1500]], 2 => [[1500], [1500, 1500]] }, sweep_bonus: 0.5)

    assert_equal [1], odds.line_moneylines.keys
    assert_match(/\A-\d+\z/, odds.line_moneylines[1][:mine])
  end

  private

  def lines_of(count, ours, theirs)
    (1..count).index_with { [ours, theirs] }
  end

  def implied(moneyline)
    return 0.5 if moneyline == 'EVEN'

    number = moneyline.to_f.abs
    moneyline.start_with?('-') ? number / (number + 100) : 100 / (number + 100)
  end
end
