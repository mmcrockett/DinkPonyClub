# frozen_string_literal: true

module League
  class SnapshotImport
    class Error < StandardError
    end

    STATUS_MAP = { 'yes' => 'in', 'no' => 'out', 'maybe' => 'maybe' }.freeze

    attr_reader :data, :force, :report

    def initialize(data, force: false)
      @data = data
      @force = force
      @report = Report.new
    end

    def call
      ActiveRecord::Base.transaction { seed_records }
      report
    end

    private

    def seed_records
      @season = import_season
      @teams = import_teams
      @players = RosterImport.new(@season, @teams, report).import(data['players'])
      @match_nights = MatchNightImport.new(@season, data['canceledDates'], report).import(data['weeks'])
      import_matches
      import_availability
    end

    def import_season
      existing = Season.find_by(name: data['name'])
      raise Error, "Season #{data['name']} already exists. Re-run with FORCE=1 to replace it." if existing && !force

      season = existing || Season.new(name: data['name'])
      existing ? reset_and_count_season(season) : report.increment_seasons_created
      apply_season_attributes(season)
      season.tap(&:save!)
    end

    def reset_and_count_season(season)
      season.match_nights.destroy_all
      season.matches.destroy_all
      report.increment_seasons_matched
    end

    def apply_season_attributes(season)
      dates = data['weeks'].filter_map { |week| week['date'] }.sort
      season.starts_on = dates.first
      season.ends_on = dates.last
      season.sweep_bonus = data['archived'] ? 1.0 : 0.5
      season.rules = data['rules']
    end

    def import_teams
      data['teams'].to_h do |name|
        team = Team.find_or_create_by!(name: name)
        team.previously_new_record? ? report.increment_teams_created : report.increment_teams_matched
        [name, team]
      end
    end

    def import_matches
      data['matches'].each { |json_match| import_match(json_match) }
    end

    def import_match(json_match)
      home_team = resolvable_team(json_match, 'a')
      away_team = resolvable_team(json_match, 'b')
      night = resolvable_night(json_match)
      return unless home_team && away_team && night

      match = Match.create!(season: @season, match_night: night, home_team: home_team, away_team: away_team)
      report.increment_matches
      MatchImport.new(match, json_match, @players, report).call
    end

    def resolvable_team(json_match, side)
      name = json_match[side]
      if name == 'TBD'
        report.warn("Match #{json_match['id']}: side #{side} is TBD, skipped.")
        return nil
      end

      return @teams[name] if @teams.key?(name)

      report.warn("Match #{json_match['id']}: unknown team #{name}, skipped.")
      nil
    end

    def resolvable_night(json_match)
      return @match_nights[json_match['week']] if @match_nights.key?(json_match['week'])

      report.warn("Match #{json_match['id']}: unknown week #{json_match['week']}, skipped.")
      nil
    end

    def import_availability
      data['players'].each { |person| import_player_availability(person) }
    end

    def import_player_availability(person)
      player = @players.fetch(person['name'])
      Array(person['availability']).sort_by { |week_id, _status| week_id.to_i }.each do |week_id, status|
        import_availability_entry(player, week_id, status)
      end
    end

    def import_availability_entry(player, week_id, status)
      mapped = STATUS_MAP[status]
      return if status == 'unknown'
      return report.warn("Unrecognized availability status \"#{status}\" for #{player.full_name}.") unless mapped

      night = @match_nights[week_id.to_i]
      return unless night

      availability = MatchAvailability.find_or_initialize_by(match_night: night, player: player)
      availability.status = mapped
      availability.save!
      report.increment_availabilities
    end
  end
end
