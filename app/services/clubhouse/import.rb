# frozen_string_literal: true

module Clubhouse
  class Import
    class Invalid < StandardError; end
    TOP_KEYS = %w[id name archived teams weeks matches players announcements rules fee paymentUrl canceledDates
                  snapshotStandings snapshotStats importWarnings].freeze
    PLAYER_KEYS = %w[id name email contactEmail phone team rank paid shirt hat shirtPaid hatPaid availability
                     excludeFromRankings].freeze
    LIMITS = { 'players' => 300, 'matches' => 100, 'weeks' => 30, 'teams' => 30 }.freeze
    SIDES = %w[a b].freeze

    def self.prepare(raw)
      new(raw).prepare
    end

    def self.create!(raw, current: false)
      data = prepare(raw)
      ClubhouseSeason.transaction do
        ClubhouseSeason.where(current: true).find_each { |season| season.update!(current: false) } if current
        ClubhouseSeason.create!(slug: data['id'], payload: data, current: current)
      end
    end

    def initialize(raw)
      raise Invalid, 'Invalid season document.' unless raw.is_a?(Hash)

      @data = raw.slice(*TOP_KEYS).deep_dup
    end

    def prepare
      validate_header
      validate_lists
      validate_weeks
      @data['players'] = @data['players'].map { |person| prepare_player(person) }
      accounts = @data['players'].filter_map { |person| person['accountId'] }
      raise Invalid, 'An account is assigned to two players.' unless accounts.uniq.size == accounts.size

      @data['matches'].each { |match| validate_match(match) }
      @data['announcements'] ||= []
      @data['rules'] = @data['rules'].to_s
      @data['paymentUrl'] = 'https://venmo.com/u/hudson2508'
      @data
    rescue Date::Error, TypeError, NoMethodError
      raise Invalid, 'Malformed season document.'
    end

    private

    def short_text?(value, maximum = 200)
      value.is_a?(String) && value.size.between?(1, maximum)
    end

    def validate_header
      slug = @data['id']
      raise Invalid, 'Invalid season ID.' unless slug.is_a?(String) && slug.match?(/\A[a-z0-9-]{1,60}\z/)
      raise Invalid, 'Invalid season name.' unless short_text?(@data['name'], 100)
    end

    def validate_lists
      LIMITS.each do |key, maximum|
        rows = @data[key]
        raise Invalid, "Invalid #{key}." unless rows.is_a?(Array) && rows.size <= maximum
        next if key == 'teams'

        raise Invalid, "Invalid #{key} rows." unless rows.all? { |row| row.is_a?(Hash) && row['id'].present? }
        raise Invalid, "Duplicate #{key} identifiers." unless rows.pluck('id').uniq.size == rows.size
      end
      raise Invalid, 'Invalid teams.' unless @data['teams'].all? { |team| short_text?(team, 100) }
    end

    def validate_weeks
      @data['weeks'].each do |week|
        raise Invalid, 'Invalid week.' unless week['id'].is_a?(Integer) && short_text?(week['label'])

        Date.iso8601(week['date'])
      end
    end

    def prepare_player(person)
      unless short_text?(person['id']) && short_text?(person['name']) && short_text?(person['team'])
        raise Invalid,
              'Invalid player.'
      end

      clean = person.slice(*PLAYER_KEYS)
      clean['email'] = clean['email'].to_s.strip.downcase
      clean['rank'] = clean['rank'].to_s
      clean['accountId'] = Player.find_by(email: clean['email'])&.id if clean['email'].present?
      clean['availability'] = {} unless clean['availability'].is_a?(Hash)
      clean
    end

    def validate_match(match)
      raise Invalid, 'Unknown week.' unless @data['weeks'].any? { |week| week['id'] == match['week'] }
      raise Invalid, 'Invalid teams.' unless SIDES.all? { |side| (@data['teams'] + ['TBD']).include?(match[side]) }

      lines = match['lines']
      raise Invalid, 'Invalid line count.' unless lines.is_a?(Array) && lines.size.between?(1, 5)

      lines.each { |line| validate_line(line) }
    end

    def validate_line(line)
      raise Invalid, 'Invalid line.' unless line.is_a?(Hash) && line['line'].is_a?(Integer)
      raise Invalid, 'Invalid lineup.' unless SIDES.all? { |side| valid_names?(line[side]) }

      scores = line['scores']
      raise Invalid, 'Invalid scores.' unless scores.is_a?(Array) && scores.size.between?(1, 3)
      raise Invalid, 'Invalid game scores.' unless scores.all? { |pair| valid_score?(pair) }
    end

    def valid_names?(names)
      names.is_a?(Array) && names.size.between?(2, 3) && names.all? { |name| name.is_a?(String) && name.size <= 200 }
    end

    def valid_score?(pair)
      pair.is_a?(Array) && pair.size == 2 && pair.all? do |value|
        value.nil? || (value.is_a?(Integer) && value.between?(0, 99))
      end
    end
  end
end
