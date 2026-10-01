# frozen_string_literal: true

module League
  class SnapshotImport
    class Error < StandardError
    end

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
      @players = import_roster
      @match_nights = MatchNightImport.new(@season, data['canceledDates'], report).import(data['weeks'])
      import_matches
      import_availability
    end

    def import_roster
      players = RosterImport.new(@season, @teams, report).import(data['players'])
      FeeImport.new(@season, players, report).import(data['fee'], data['players']) unless data['archived']
      players
    end

    def import_availability
      AvailabilityImport.new(@match_nights, @players, report).import(data['players'])
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
      warn_before_reset(season)
      season.match_nights.destroy_all
      season.matches.destroy_all
      season.fees.destroy_all
      report.increment_seasons_matched
    end

    def warn_before_reset(season)
      slot_count = MatchSlot.where(match_night: season.match_nights).count
      return if slot_count.zero?

      report.warn("FORCE re-import is deleting #{slot_count} match slot(s) (and their availability) for " \
                  "#{season.name} - these are not part of the clubhouse export.")
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
      return unless rostered_teams?(json_match, home_team, away_team)

      match = Match.create!(season: @season, match_night: night, home_team: home_team, away_team: away_team)
      report.increment_matches
      MatchImport.new(match, json_match, @players, report).call
    end

    def rostered_teams?(json_match, home_team, away_team)
      missing = [home_team, away_team].reject { |team| team.roster_for(@season).exists? }
      return true if missing.empty?

      report.warn("Match #{json_match['id']}: #{missing.map(&:name).join(', ')} has no roster for this season, " \
                  'skipped.')
      false
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
  end
end
