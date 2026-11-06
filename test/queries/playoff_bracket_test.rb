require 'test_helper'

class PlayoffBracketTest < ActiveSupport::TestCase
  setup do
    @setup = build_playoff_season
    League::PlayoffBracket.new(@setup.night).seed!
    @first, @second = @setup.night.matches.order(:id).to_a
  end

  test 'is empty for a night without round matches' do
    assert_not_predicate PlayoffBracket.new(match_nights(:fall_week_one)), :any?
  end

  test 'advances nobody until a semifinal is complete' do
    bracket = PlayoffBracket.new(@setup.night)

    assert_predicate bracket, :any?
    assert_nil bracket.advancing(@first)
    assert_not bracket.ready_for_final?
  end

  test 'advances the semifinal winner and is ready once both are done' do
    score_match!(@first, @setup.players, sweep(5, 11))
    score_match!(@second, @setup.players, sweep(11, 5))
    bracket = PlayoffBracket.new(@setup.night.reload)

    assert_equal @setup.teams[3], bracket.advancing(@first)
    assert_predicate bracket, :ready_for_final?
  end

  test 'sends the higher seed through on a dead tie' do
    score_match!(@first, @setup.players, [[11, 5], [5, 11], [11, 5]])
    score_match!(@first, @setup.players, [[5, 11], [11, 5], [5, 11]], position: 2)

    assert_equal @setup.teams[0], PlayoffBracket.new(@setup.night.reload).advancing(@first)
  end

  test 'names the champion from the final' do
    score_match!(@first, @setup.players, sweep(11, 5))
    score_match!(@second, @setup.players, sweep(11, 5))
    final = League::PlayoffBracket.new(@setup.night.reload).create_final!
    score_match!(final, @setup.players, sweep(5, 11))

    assert_equal @setup.teams[1], PlayoffBracket.new(@setup.night.reload).champion
  end
end
