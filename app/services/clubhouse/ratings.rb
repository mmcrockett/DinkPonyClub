# frozen_string_literal: true

module Clubhouse
  # Chronological doubles Elo. All starting strengths come from the earliest roster.
  class Ratings
    ALIASES = JSON.parse(File.read(File.expand_path('../../../clubhouse/lib/elo-aliases.json', __dir__))).freeze
    SIDES = %w[a b].freeze
    ROTATION = [[0, 1], [0, 2], [1, 2]].freeze

    def self.identity(season, name)
      key = name.to_s.downcase.gsub(/[^a-z0-9 ]/, '').strip.gsub(/\s+/, ' ')
                .sub(/^matthew /, 'matt ').sub('ryan mcclagan', 'ryan mclagan').sub('stepehen walsh', 'stephen walsh')
      scoped = "#{season['id']}|#{key}"
      return ALIASES[scoped] if ALIASES.key?(scoped)
      return scoped if key.split.size < 2 || key.split.last.size < 2

      key
    end

    def self.complete?(match)
      return true if match['reported']

      scores = match['lines'].flat_map { |line| line['scores'] }
      scores.any? && scores.all? do |first, second|
        valid_score?(first, second) && (first != second || match.key?('sweepBonus'))
      end
    end

    def self.valid_score?(first, second)
      [first, second].all? { |score| score.is_a?(Numeric) && score >= 0 } && [first, second] != [0, 0]
    end

    def self.pairs(season, line, game)
      SIDES.map do |side|
        names = line[side]
        slots = names[2].to_s.empty? ? ROTATION[0] : ROTATION[game]
        (slots || []).map { |index| names[index].to_s.empty? ? nil : identity(season, names[index]) }
      end
    end

    def initialize(history)
      @history = history
    end

    def calculate(selected, lifetime: false)
      cutoff = lifetime ? @history.flat_map { |season| dates(season) }.max : dates(selected).max
      eligible = eligible_seasons(cutoff)
      events = events_for(eligible, cutoff)
      ratings = seed_ratings(eligible, events)
      notes = []
      each_game(events) { |season, pairs, scores| rate_game(season, pairs, scores, ratings, notes) }
      result = selected['players'].to_h do |player|
        [player['id'], ratings[self.class.identity(selected, player['name'])] || initial_rating]
      end
      { ratings: result, notes: notes.uniq.sort }
    end

    def career(selected)
      records = {}
      each_game(events_for(@history)) do |_, pairs, scores|
        pairs.each_with_index do |pair, side|
          outcome = outcome_for(scores, side)
          pair.each { |key| record_game(records, key, outcome) }
        end
      end
      selected['players'].to_h do |player|
        [player['id'], records[self.class.identity(selected, player['name'])] || empty_record]
      end
    end

    private

    def dates(season)
      season['weeks'].filter_map { |week| week['date'] }.sort
    end

    def eligible_seasons(cutoff)
      eligible = @history.select { |season| dates(season).first && dates(season).first <= cutoff.to_s }
      eligible.sort_by { |season| [dates(season).first, season['id']] }
    end

    def events_for(seasons, cutoff = '9999-12-31')
      events = seasons.flat_map do |season|
        season['matches'].filter_map do |match|
          date = season['weeks'].find { |week| week['id'] == match['week'] }&.fetch('date')
          [date, season, match] if date && date <= cutoff.to_s
        end
      end
      events.sort_by { |date, season, match| [date, season['id'], match['week'], match['id']] }
    end

    def each_game(events)
      events.each do |_, season, match|
        next unless self.class.complete?(match)

        match['lines'].sort_by { |line| line['line'] }.each do |line|
          line['scores'].each_with_index do |scores, game|
            pairs = self.class.pairs(season, line, game)
            next unless self.class.valid_score?(*scores) && valid_pairs?(pairs)

            yield season, pairs, scores
          end
        end
      end
    end

    def valid_pairs?(pairs)
      keys = pairs.flatten
      keys.size == 4 && keys.uniq.size == 4 && keys.none?(&:nil?)
    end

    def seed_ratings(seasons, events)
      ratings = {}
      seasons.each do |season|
        count = [1, *season['matches'].map { |match| match['lines'].size }].max
        season['players'].each do |player|
          key = self.class.identity(season, player['name'])
          tier = rank_tier(player['rank'], count) || first_line(season, key, events)
          ratings[key] ||= initial_rating(tier, count)
        end
      end
      ratings
    end

    def rank_tier(value, count)
      rank = value.to_s.strip.upcase
      tier = rank.ord - 64 if rank.match?(/\A[A-D]\z/)
      tier = rank[0].to_i if rank.match?(/\A[1-5][A-C]?\z/)
      tier if tier&.between?(1, count)
    end

    def first_line(season, key, events)
      events.each do |_, event_season, match|
        next unless event_season['id'] == season['id'] && self.class.complete?(match)

        line = match['lines'].sort_by { |item| item['line'] }.find do |item|
          (item['a'] + item['b']).any? { |name| !name.to_s.empty? && self.class.identity(season, name) == key }
        end
        return line['line'] if line
      end
      nil
    end

    def initial_rating(tier = nil, count = 1)
      { 'elo' => tier ? 1500 + (100 * (((count + 1) / 2.0) - tier)) : 1500, 'ratedGames' => 0 }
    end

    def rate_game(season, pairs, scores, ratings, notes)
      keys = pairs.flatten
      return unless keys.all? { |key| ratings.key?(key) }

      keys.each { |key| notes << "#{season['name']}: #{key.split('|')[1]}" if key.include?('|') }
      average = pairs.map { |pair| pair.sum { |key| ratings[key]['elo'] } / 2.0 }
      expected = 1 / (1 + (10**((average[1] - average[0]) / 400.0)))
      actual = { 'wins' => 1, 'ties' => 0.5, 'losses' => 0 }.fetch(outcome_for(scores, 0))
      delta = 24 * (actual - expected)
      pairs.each_with_index do |pair, side|
        pair.each do |key|
          ratings[key]['elo'] += side.zero? ? delta : -delta
          ratings[key]['ratedGames'] += 1
        end
      end
    end

    def outcome_for(scores, side)
      return 'ties' if scores[0] == scores[1]

      scores[side] > scores[1 - side] ? 'wins' : 'losses'
    end

    def record_game(records, key, outcome)
      row = (records[key] ||= empty_record)
      row['games'] += 1
      row[outcome] += 1
      row['winRate'] = row['wins'].fdiv(row['games'])
    end

    def empty_record
      { 'wins' => 0, 'losses' => 0, 'ties' => 0, 'games' => 0, 'winRate' => 0 }
    end
  end
end
