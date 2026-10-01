require 'test_helper'

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  test 'returns a text/calendar feed of the player team nights only' do
    get schedule_calendar_path(token: players(:ada).calendar_token)

    assert_response :success
    assert_equal 'text/calendar', response.media_type
    uids = events.map { |event| event.uid.to_s }

    assert_equal [uid_for(:fall_week_one), uid_for(:fall_upcoming)], uids
  end

  test 'serves the feed without a browser user agent or session' do
    get schedule_calendar_path(token: players(:ada).calendar_token),
        headers: { 'User-Agent' => 'Google-Calendar-Importer' }

    assert_response :success
  end

  test 'returns 404 for an unknown token' do
    get schedule_calendar_path(token: 'not-a-real-token')

    assert_response :not_found
  end

  test 'returns 404 with no token' do
    get schedule_calendar_path

    assert_response :not_found
  end

  test 'returns 404 for an inactive player' do
    get schedule_calendar_path(token: players(:wade).calendar_token)

    assert_response :not_found
  end

  test 'returns an empty but valid calendar for a player with no roster spot' do
    get schedule_calendar_path(token: players(:zoe).calendar_token)

    assert_response :success
    assert_equal 1, calendars.size
    assert_empty events
  end

  test 'emits a timed UTC event when the night has slots' do
    get schedule_calendar_path(token: players(:ada).calendar_token)

    event = event_for(:fall_upcoming)

    assert_equal match_slots(:fall_future_slot_one).starts_at.utc, event.dtstart.to_time.utc
    assert_equal match_slots(:fall_future_slot_three).starts_at.utc + 1.hour, event.dtend.to_time.utc
    assert_match(/DTSTART:\d{8}T\d{6}Z/, response.body)
  end

  test 'emits an all-day event with notes when the night has no slots' do
    match_nights(:fall_week_one).update!(notes: 'Lines 2 & 4 at 7:15 PM', venue: 'Court House')

    get schedule_calendar_path(token: players(:ada).calendar_token)

    event = event_for(:fall_week_one)

    assert_instance_of Icalendar::Values::Date, event.dtstart
    assert_equal match_nights(:fall_week_one).played_on, event.dtstart.value
    assert_equal 'Court House', event.location.to_s
    assert_includes event.description.to_s, 'Lines 2 & 4 at 7:15 PM'
    assert_includes event.description.to_s, match_night_url(match_nights(:fall_week_one))
  end

  test 'describes the player own availability' do
    get schedule_calendar_path(token: players(:grace).calendar_token)

    assert_includes event_for(:fall_upcoming).description.to_s, 'Your availability: Out'
    assert_includes event_for(:fall_week_one).description.to_s, 'Your availability: Not set'
  end

  test 'summarizes the matchup and escapes commas in team names' do
    teams(:alpha).update!(name: 'Old Balls, New Flicks')

    get schedule_calendar_path(token: players(:ada).calendar_token)

    assert_equal 'Old Balls, New Flicks vs Test Team Bravo', event_for(:fall_week_one).summary.to_s
    assert_includes response.body, 'Old Balls\, New Flicks'
  end

  test 'keeps a canceled night in the feed, marked canceled' do
    match_nights(:fall_upcoming).update!(canceled: true)

    get schedule_calendar_path(token: players(:ada).calendar_token)

    event = event_for(:fall_upcoming)

    assert_equal '[Canceled] Test Team Alpha vs Test Team Bravo', event.summary.to_s
    assert_equal 'CANCELLED', event.status.to_s
  end

  test 'keeps the UID stable and bumps SEQUENCE when a night is edited' do
    get schedule_calendar_path(token: players(:ada).calendar_token)
    before = event_for(:fall_week_one)

    travel 1.minute do
      match_nights(:fall_week_one).update!(venue: 'New venue')
    end
    get schedule_calendar_path(token: players(:ada).calendar_token)
    after = event_for(:fall_week_one)

    assert_equal before.uid.to_s, after.uid.to_s
    assert_operator after.sequence.to_i, :>, before.sequence.to_i
  end

  test 'answers a conditional GET with 304 until the schedule changes' do
    get schedule_calendar_path(token: players(:ada).calendar_token)
    etag = response.headers['ETag']

    get schedule_calendar_path(token: players(:ada).calendar_token), headers: { 'If-None-Match' => etag }

    assert_response :not_modified

    travel 1.minute do
      match_slots(:fall_future_slot_one).update!(starts_at: match_slots(:fall_future_slot_one).starts_at - 30.minutes)
    end
    get schedule_calendar_path(token: players(:ada).calendar_token), headers: { 'If-None-Match' => etag }

    assert_response :success
  end

  test 'a deleted slot invalidates the ETag' do
    get schedule_calendar_path(token: players(:ada).calendar_token)
    etag = response.headers['ETag']

    match_slots(:fall_future_slot_three).destroy!
    get schedule_calendar_path(token: players(:ada).calendar_token), headers: { 'If-None-Match' => etag }

    assert_response :success
  end

  test 'a team rename invalidates the ETag' do
    get schedule_calendar_path(token: players(:ada).calendar_token)
    etag = response.headers['ETag']

    travel 1.minute do
      teams(:alpha).update!(name: 'Renamed Alpha')
    end
    get schedule_calendar_path(token: players(:ada).calendar_token), headers: { 'If-None-Match' => etag }

    assert_response :success
    assert_includes event_for(:fall_week_one).summary.to_s, 'Renamed Alpha'
  end

  private

  def calendars
    Icalendar::Calendar.parse(response.body)
  end

  def events
    calendars.first.events
  end

  def event_for(night_name)
    events.find { |event| event.uid.to_s == uid_for(night_name) }
  end

  def uid_for(night_name)
    "match-night-#{match_nights(night_name).id}@dinkponyclub.org"
  end
end
