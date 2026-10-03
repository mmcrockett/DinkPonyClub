require 'test_helper'

class PlayerRatingsTest < ActiveSupport::TestCase
  setup do
    @season = seasons(:scorecard)
    @ada = players(:ada)
    @sam = players(:sam)
  end

  test 'a win between equal sides moves both partners by the same amount' do
    play(11, 9)

    ratings = PlayerRatings.new(@season)

    assert_in_delta 1512, ratings.for(@ada.id).elo
    assert_in_delta 1512, ratings.for(players(:grace).id).elo
    assert_in_delta 1488, ratings.for(@sam.id).elo
    assert_equal 1, ratings.for(@ada.id).games
  end

  test 'a lopsided score moves ratings more than a close one' do
    play(11, 0)

    assert_in_delta 1518, PlayerRatings.new(@season).for(@ada.id).elo
  end

  test 'an upset costs the favorite more than an expected win gains' do
    play(11, 9)
    play(9, 11, number: 2)

    assert_operator PlayerRatings.new(@season).for(@ada.id).elo, :<, 1500
  end

  test 'ratings are zero-sum across the four players' do
    play(11, 4)
    play(7, 11, number: 2)

    ratings = PlayerRatings.new(@season)

    assert_in_delta 6000, total(ratings)
  end

  test 'earlier seasons only see games up to their last match night' do
    play(11, 9)

    assert_equal 1, PlayerRatings.new(@season).for(@ada.id).games
    assert_equal 4, PlayerRatings.new(seasons(:fall)).for(@ada.id).games
  end

  test 'new players are seeded from their draft rank' do
    set_ranks('1', '4')
    Lineup.create!(match: matches(:fall_alpha_bravo), position: 4)

    ratings = PlayerRatings.new(seasons(:fall))

    assert_in_delta 6000, total(ratings)
  end

  test 'new players without a rank are seeded from the line they first play' do
    Lineup.create!(match: matches(:fall_alpha_bravo), position: 4)

    ratings = PlayerRatings.new(seasons(:fall))

    assert_in_delta 7020, total(ratings)
  end

  test 'rostered players without games show their seed and no rated games' do
    Lineup.create!(match: matches(:fall_alpha_bravo), position: 4)
    ranked = roster('Ranked', '2B')
    unranked = roster('Unranked', nil)

    ratings = PlayerRatings.new(seasons(:fall))

    assert_in_delta 1585, ratings.for(ranked.id).elo
    assert_equal 0, ratings.for(ranked.id).games
    assert_nil ratings.for(unranked.id)
  end

  test 'pupr maps 1500 to 3.5 and 400 points to one rating point' do
    assert_in_delta 3.5, PlayerRatings::Rating.new(1500.0, 0).pupr
    assert_in_delta 4.5, PlayerRatings::Rating.new(1900.0, 0).pupr
    assert_in_delta 2.0, PlayerRatings::Rating.new(0.0, 0).pupr
  end

  private

  def total(ratings)
    [@ada, players(:grace), @sam, players(:ben)].sum { |player| ratings.for(player.id).elo }
  end

  def play(home_score, away_score, number: 1)
    lineup = Lineup.find_or_create_by!(match: matches(:scorecard_match), position: 1)
    Game.create!(lineup: lineup, number: number, home_score: home_score, away_score: away_score,
                 home_player_a: @ada, home_player_b: players(:grace), away_player_a: @sam, away_player_b: players(:ben))
  end

  def set_ranks(home_rank, away_rank)
    %i[ada grace].each { |name| roster_spot(name).update!(draft_rank: home_rank) }
    %i[sam ben].each { |name| roster_spot(name).update!(draft_rank: away_rank) }
  end

  def roster_spot(name)
    RosterSpot.find_by!(season: seasons(:fall), player: players(name))
  end

  def roster(first_name, rank)
    player = Player.create!(first_name: first_name, last_name: 'Test')
    RosterSpot.create!(season: seasons(:fall), team: teams(:alpha), player: player, draft_rank: rank)
    player
  end
end
