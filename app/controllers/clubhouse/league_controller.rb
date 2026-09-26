# frozen_string_literal: true

module Clubhouse
  class LeagueController < BaseController
    BOOLEAN_VALUES = [true, false].freeze
    rescue_from Import::Invalid do |error|
      render json: { error: error.message }, status: :unprocessable_content
    end
    rescue_from ActiveRecord::StaleObjectError do
      render json: { error: 'Someone updated this season. Reload before saving.' }, status: :conflict
    end

    def show
      selected = ClubhouseSeason.find_by!(slug: request.query_parameters['season'].presence || current_season.slug)
      history = ClubhouseSeason.order(:id).map(&:snapshot)
      career = {}
      history.sort_by { |s| s['weeks'].map { |w| w['date'] }.min.to_s }.each do |season|
        access.serialize(season, history, lifetime: true)['players'].each do |person|
          key = Ratings.identity(season, person['name'])
          career[key] = person.merge('id' => "career-#{key}")
        end
      end
      render json: { season: access.serialize(selected.snapshot, history),
                     lifetimePlayers: career.values, seasons: history.map { |s| s.slice('id', 'name') },
                     privateAccess: !!(access.admin? || access.captain?), captain: !!access.captain?,
                     admin: !!access.admin?, local: false, playerId: access.member(selected.payload)&.fetch('id') }
    end

    def update
      raise Import::Invalid, 'Request too large.' if request.raw_post.bytesize > 2.megabytes

      @body = JSON.parse(request.raw_post)
      raise Import::Invalid, 'Invalid request.' unless @body.is_a?(Hash)

      action = @body['action']
      captain_action = %w[result teamAvailability].include?(action)
      if (captain_action && !access.captain?) || (!captain_action && %w[availability
                                                                        profile].exclude?(action) && !access.admin?)
        return render json: { error: 'You do not have permission to make this change.' }, status: :forbidden
      end

      if action == 'import'
        row = Import.create!(@body['data'])
        return render json: { ok: true, seasonId: row.slug }
      end
      row = ClubhouseSeason.find_by!(slug: @body['seasonId'] || current_season.slug)
      return render json: { error: 'Archived seasons are read-only.' }, status: :forbidden if row.payload['archived']
      unless @body['revision'].is_a?(Integer) && @body['revision'] == row.lock_version
        raise ActiveRecord::StaleObjectError.new(row,
                                                 'update')
      end

      @season = row.snapshot
      @self = access.member(@season)
      case action
      when 'availability', 'teamAvailability' then update_availability(action)
      when 'profile' then update_profile
      when 'result' then update_result
      when 'payment' then update_payment
      when 'announcement'
        title = text('title', 150)
        content = text('body', 6000)
        raise Import::Invalid, 'A title and message are required.' if title.empty? || content.empty?

        @season['announcements'].unshift({ 'id' => SecureRandom.uuid, 'title' => title, 'body' => content,
                                           'date' => Time.current.iso8601 })
      when 'rules'
        @season['rules'] = text('rules', 15_000)
        raise Import::Invalid, 'Rules cannot be blank.' if @season['rules'].empty?
      when 'schedule' then update_schedule
      else raise Import::Invalid, 'Unknown action.'
      end
      row.update!(payload: @season.except('revision'))
      render json: { ok: true }
    rescue JSON::ParserError
      render json: { error: 'Invalid JSON.' }, status: :bad_request
    end

    private

    def text(key, limit)
      @body[key].is_a?(String) ? @body[key].strip.first(limit) : ''
    end

    def target
      @season['players'].find { |p| p['id'] == @body['playerId'] } || raise(Import::Invalid, 'Player not found.')
    end

    def update_availability(action)
      if action == 'availability' && (!@self || (@body['playerId'] && @body['playerId'] != @self['id']))
        raise Import::Invalid,
              'Personal availability belongs to the signed-in player. Use Team availability for others.'
      end

      person = action == 'teamAvailability' ? target : @self
      week = @season['weeks'].find { |w| w['id'] == @body['week'] }
      raise Import::Invalid, 'Choose a week and availability.' unless week && %w[yes no maybe
                                                                                 unknown].include?(@body['value'])

      person['availability'] ||= {}
      same_night = @season['weeks'].select { |w| w['date'] == week['date'] }
      same_night.each { |w| person['availability'][w['id'].to_s] = @body['value'] }
    end

    def update_profile
      person = access.admin? ? target : @self
      raise Import::Invalid, 'Your account has no player in this season.' unless person
      if !access.admin? && @body['playerId'] && @body['playerId'] != person['id']
        raise Import::Invalid,
              'Cannot edit another player.'
      end
      if @body.key?('captain') && @body['captain'] != access.captain_name?(@season, person)
        raise Import::Invalid, 'Captain access is managed by the organizer roster.'
      end

      person['phone'] = text('phone', 40)
      person['contactEmail'] = text('contactEmail', 254)
      validate_email!(person['contactEmail'])
      return unless access.admin? && @body['email'].is_a?(String)

      email = text('email', 254).downcase
      validate_email!(email)
      account = email.present? ? Player.find_by(email: email) : nil
      raise Import::Invalid, 'Create that player account in Admin Players first.' if email.present? && !account
      if account && @season['players'].any? { |p| p['id'] != person['id'] && p['accountId'] == account.id }
        raise Import::Invalid, 'That account is already linked.'
      end

      person['email'] = email
      person['accountId'] = account&.id
    end

    def validate_email!(email)
      raise Import::Invalid, 'Enter a valid email.' if email.present? && !email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def update_result
      match = @season['matches'].find { |m| m['id'] == @body['matchId'] }
      raise Import::Invalid, 'Assign matchup teams first.' unless match && match['a'] != 'TBD' && match['b'] != 'TBD'

      lines = @body['lines']
      raise Import::Invalid, 'All five lines are required.' unless lines.is_a?(Array) && lines.size == 5

      known = @season['players'].pluck('name')
      lines.each_with_index do |line, i|
        raise Import::Invalid, 'Invalid line.' unless line.is_a?(Hash) && line['line'] == i + 1

        Ratings::SIDES.each do |side|
          raise Import::Invalid, 'Check the lineup.' unless valid_lineup?(line[side], known)
        end
        if line['a'].reject(&:empty?).intersect?(line['b'].reject(&:empty?))
          raise Import::Invalid,
                'A player cannot play both sides.'
        end

        scores = line['scores']
        next if scores.is_a?(Array) && scores.size == 3 && scores.all? do |pair|
          pair.is_a?(Array) && pair.size == 2 && pair.all? do |n|
            n.is_a?(Integer) && n.between?(0, 99)
          end && pair[0] != pair[1]
        end

        raise Import::Invalid, 'Enter both scores for all 15 games; no ties.'
      end
      match['lines'] = lines.map { |line| line.slice('line', 'a', 'b', 'scores') }
      match.delete('reported')
    end

    def valid_lineup?(names, known)
      return false unless names.is_a?(Array) && names.size == 3 && names.all?(String)
      return false unless names.first(2).all?(&:present?)

      playing = names.reject(&:empty?)
      playing.all? { |name| known.include?(name) } && playing.uniq.size == playing.size
    end

    def update_payment
      person = target
      %w[paid shirt hat shirtPaid hatPaid].each do |key|
        person[key] = @body[key] if @body[key].in?(BOOLEAN_VALUES)
      end
    end

    def update_schedule
      week = @season['weeks'].find { |w| w['id'] == @body['week'] }
      raise Import::Invalid, 'Choose a valid week.' unless week

      Date.iso8601(@body['date'].to_s)
      week.merge!('date' => @body['date'], 'time' => text('time', 80), 'venue' => text('venue', 150))
      raise Import::Invalid, 'Invalid matchups.' unless @body.fetch('matches', []).is_a?(Array)

      @body.fetch('matches', []).each do |item|
        match = @season['matches'].find { |m| m['week'] == week['id'] && m['id'] == item['id'] }
        raise Import::Invalid, 'Select two different teams.' unless match && Ratings::SIDES.all? do |key|
          (@season['teams'] + ['TBD']).include?(item[key])
        end && (item['a'] != item['b'] || item['a'] == 'TBD')
        if Ratings.complete?(match) && (match['a'] != item['a'] || match['b'] != item['b'])
          raise Import::Invalid,
                'Teams cannot change after results.'
        end

        match.merge!(item.slice('a', 'b'))
      end
    rescue Date::Error
      raise Import::Invalid, 'Choose a valid date.'
    end
  end
end
