require 'test_helper'

module Clubhouse
  class RatingsTest < ActiveSupport::TestCase
    def season(id, date, names: %w[Alpha Bravo Charlie Delta], score: [11, 5])
      players = names.each_with_index.map { |name, i| { 'id' => i.to_s, 'name' => "#{name} Player", 'rank' => '1' } }
      line = { 'line' => 1, 'a' => players.first(2).pluck('name'),
               'b' => players.last(2).pluck('name'), 'scores' => [score] }
      { 'id' => id, 'name' => id, 'weeks' => [{ 'id' => 1, 'date' => date }], 'players' => players,
        'matches' => [{ 'id' => 'match', 'week' => 1, 'lines' => [line] }] }
    end

    test 'ratings carry across seasons and historical views exclude later games' do
      spring = season('spring', '2026-01-01')
      fall = season('fall', '2026-09-01')
      calculator = Ratings.new([fall, spring])

      assert_equal 1512, calculator.calculate(spring)[:ratings]['0']['elo']
      assert_operator calculator.calculate(fall)[:ratings]['0']['elo'], :>, 1512
      assert_equal 2, calculator.calculate(fall)[:ratings]['0']['ratedGames']
      assert_equal 2, calculator.career(fall)['0']['wins']
    end

    test 'stronger opposition changes the expected result' do
      data = season('fall', '2026-09-01')
      # Four tiers establish a strength prior; empty lines do not add results.
      data['matches'][0]['lines'] += (2..4).map do |i|
        { 'line' => i, 'a' => ['', ''], 'b' => ['', ''], 'scores' => [[nil, nil]] }
      end
      data['matches'][0]['reported'] = { 'a' => 1, 'b' => 0 }
      data['players'].last(2).each { |p| p['rank'] = '4' }
      rating = Ratings.new([data]).calculate(data)[:ratings]['0']['elo']

      assert_operator rating, :>, 1650
      assert_operator rating, :<, 1662
    end

    test 'rotating pairs receive only their actual games' do
      data = season('fall', '2026-09-01', names: %w[Alpha Bravo Charlie Delta Echo Foxtrot])
      line = data['matches'][0]['lines'][0]
      line['a'] = data['players'].first(3).pluck('name')
      line['b'] = data['players'].last(3).pluck('name')
      line['scores'] = [[11, 5], [5, 11], [11, 5]]

      assert_equal [2], Ratings.new([data]).career(data).values.pluck('games').uniq
    end
  end
end
