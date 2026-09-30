# frozen_string_literal: true

class PlayerCalendar
  UID_DOMAIN = 'dinkponyclub.org'
  LAST_SLOT_DURATION = 1.hour
  NIGHT_INCLUDES = [:match_slots, { matches: %i[home_team away_team] }].freeze

  attr_reader :player, :season

  def initialize(player, season, night_url:)
    @player = player
    @season = season
    @night_url = night_url
  end

  def match_nights
    @match_nights ||= load_match_nights
  end

  def last_modified
    match_nights.map { |night| updated_at_for(night) }.max
  end

  def cache_key
    [season&.id, team&.id, match_nights.map(&:id), last_modified&.to_i]
  end

  def to_ical
    calendar = Icalendar::Calendar.new
    calendar.prodid = '-//Dink Pony Club//Schedule//EN'
    calendar.append_custom_property('X-WR-CALNAME', I18n.t('calendars.show.calendar_name', name: player.full_name))
    match_nights.each { |night| calendar.add_event(event_for(night)) }
    calendar.publish
    calendar.to_ical
  end

  private

  def team
    return @team if defined?(@team)

    @team = season && player.teams.merge(RosterSpot.where(season: season)).first
  end

  def load_match_nights
    return [] unless team

    season.match_nights
          .where(id: team.matches_in(season).select(:match_night_id))
          .chronological
          .includes(NIGHT_INCLUDES)
          .to_a
  end

  def availabilities
    @availabilities ||= MatchAvailability.where(player: player, match_night_id: match_nights.map(&:id))
                                         .index_by(&:match_night_id)
  end

  def updated_at_for(night)
    [night.updated_at, *night.match_slots.map(&:updated_at), *night.matches.map(&:updated_at),
     availabilities[night.id]&.updated_at].compact.max
  end

  def event_for(night)
    Icalendar::Event.new.tap do |event|
      assign_identity(event, night)
      assign_content(event, night)
      assign_times(event, night)
    end
  end

  def assign_identity(event, night)
    updated_at = updated_at_for(night)
    event.uid = "match-night-#{night.id}@#{UID_DOMAIN}"
    event.sequence = updated_at.to_i
    event.dtstamp = utc(updated_at)
    event.last_modified = utc(updated_at)
  end

  def assign_content(event, night)
    event.summary = summary_for(night)
    event.location = night.venue.presence
    event.description = description_for(night)
    event.url = @night_url.call(night)
    event.status = night.canceled? ? 'CANCELLED' : 'CONFIRMED'
  end

  def assign_times(event, night)
    starts = night.match_slots.map(&:starts_at)
    event.dtstart, event.dtend = starts.any? ? timed_span(starts) : all_day_span(night.played_on)
  end

  def timed_span(starts)
    [utc(starts.min), utc(starts.max + LAST_SLOT_DURATION)]
  end

  def all_day_span(date)
    [Icalendar::Values::Date.new(date), Icalendar::Values::Date.new(date + 1)]
  end

  def summary_for(night)
    summary = matchups_for(night).presence&.join(' & ') || night.label
    night.canceled? ? "#{I18n.t('calendars.show.canceled_prefix')} #{summary}" : summary
  end

  def matchups_for(night)
    night.matches.select { |match| [match.home_team_id, match.away_team_id].include?(team.id) }
         .map { |match| "#{match.home_team.name} vs #{match.away_team.name}" }
  end

  def description_for(night)
    [
      I18n.t('calendars.show.your_availability', status: availability_label(night)),
      night.notes.presence,
      @night_url.call(night)
    ].compact.join("\n\n")
  end

  def availability_label(night)
    status = availabilities[night.id]&.status || 'not_set'
    I18n.t("calendars.show.availability.#{status}")
  end

  def utc(time)
    Icalendar::Values::DateTime.new(time.utc, 'tzid' => 'UTC')
  end
end
