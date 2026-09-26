# frozen_string_literal: true

module Clubhouse
  class Access
    FALL_CAPTAINS = ['Harrison Hudson', 'Jordan Blount', 'Aabir Malik', 'Chris Bell', 'Justin Browne', 'Mike Crockett',
                     'Brooks Masterson', 'Jon Berry'].freeze

    attr_reader :player, :current

    def initialize(player, current)
      @player = player
      @current = current
    end

    def admin?
      player&.active? && player.admin?
    end

    def member(season)
      season&.fetch('players', [])&.find { |p| p['accountId'] == player&.id }
    end

    def captain_name?(season, person)
      return FALL_CAPTAINS.include?(person['name']) if season['id'] == 'fall-2026'

      # Later seasons use the site's existing, organizer-managed roster assignments.
      RosterSpot.joins(:season).exists?(player_id: person['accountId'], captain: true,
                                        seasons: { name: season['name'] })
    end

    def captain?
      person = member(current)
      player&.active? && person && captain_name?(current, person)
    end

    def allowed?(season = current)
      player&.active? && (admin? || member(current) || member(season))
    end

    def serialize(season, history, lifetime: false)
      ratings = Ratings.new(history)
      elo = ratings.calculate(season, lifetime: lifetime)
      career = ratings.career(season)
      private_access = admin? || captain?
      clean = season.deep_dup
      clean['players'] = season['players'].map do |person|
        row = person.slice('id', 'name', 'team', 'excludeFromRankings')
        row['name'] = 'Substitute (name missing)' if !private_access && row['name'].include?('@')
        row['captain'] = captain_name?(season, person)
        row['lifetime'] = career[person['id']]
        own = person['accountId'] == player.id
        row['availability'] = person['availability'] if own || private_access
        if private_access
          row.merge!(person.slice('rank', 'contactEmail', 'phone'))
          row['contactEmail'] ||= person['email']
          row.merge!(elo[:ratings][person['id']])
        end
        if own || admin?
          row.merge!(person.slice('email', 'contactEmail', 'phone', 'paid', 'shirt', 'hat', 'shirtPaid', 'hatPaid'))
        end
        row
      end
      clean['eloNotes'] = private_access ? elo[:notes] : nil
      clean['paymentUrl'] = 'https://venmo.com/u/hudson2508'
      clean['matches'].each do |match|
        match['lines'].each do |line|
          Ratings::SIDES.each do |side|
            line[side].map! do |n|
              !private_access && n.include?('@') ? 'Substitute (name missing)' : n
            end
          end
        end
      end
      # Imported diagnostics can contain source cells with contact information.
      clean.delete('importWarnings') unless admin?
      clean
    end
  end
end
