require 'test_helper'

class MatchNightsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  test 'redirects to root when signed out' do
    get season_match_nights_path(seasons(:fall))

    assert_redirected_to root_path
  end

  test 'index renders nights in chronological order' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_response :success
    assert_operator response.body.index(dom_id(match_nights(:fall_week_one))),
                    :<, response.body.index(dom_id(match_nights(:fall_playoff)))
  end

  test 'marks the first upcoming night as up next' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Up next/i
  end

  test 'shows a final pill for a completed night and scheduled for an upcoming one' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_week_one))}", text: /Final/
    assert_select "##{dom_id(match_nights(:fall_upcoming))}", text: /Scheduled/
  end

  test 'shows canceled and playoffs pills' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_canceled))}", text: /Canceled/
    assert_select "##{dom_id(match_nights(:fall_playoff))}", text: /Playoffs/
  end

  test 'canceled night shows only its label and pill' do
    night = match_nights(:fall_canceled)
    night.update!(venue: 'Rainy Courts', notes: 'Wet')
    Match.create!(season: seasons(:fall), match_night: night, home_team: teams(:alpha), away_team: teams(:bravo))
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(night)}"

    assert_select frame, text: /Canceled/
    assert_select frame, text: /Rainy Courts|Wet|Alpha/, count: 0
    assert_select "#{frame} a:not([href^='/admin'])", count: 0
  end

  test 'shows a lineup icon link for a captain on their own team' do
    sign_in_as_ada
    match = matches(:fall_future)

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?][title=?]",
                  edit_match_team_lineup_path(match, match.home_team), "Set #{match.home_team.name} lineup"
  end

  test 'hides team availability for a non-captain' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}", count: 0
  end

  test 'shows team availability for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'team view drops the personal availability buttons so each player is set in one place' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :my_availability)}", count: 0
  end

  test 'matchups view keeps the personal availability buttons' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"
  end

  test 'shows slot preference radios with the saved choice for a player who is in' do
    sign_in_as_ada
    slot = match_slots(:fall_future_slot_one)

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[name='slot_preferences[#{slot.id}]']", count: 3
    assert_select "#{frame} input[name='slot_preferences[#{slot.id}]'][value=thumbs_up][checked]"
  end

  test 'hides slot preference radios for a player who is out' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[name^='slot_preferences']", count: 0
  end

  test 'hides slot preference radios on a night with no slots' do
    sign_in_as_ada
    match_nights(:fall_upcoming).match_slots.destroy_all

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[name^='slot_preferences']", count: 0
  end

  test 'shows slot preferences read-only once availability has closed' do
    sign_in_as(players(:grace))
    match_availabilities(:fall_future_grace).update!(status: 'in')
    slot_one = match_slots(:fall_future_slot_one)
    slot_one.slot_availabilities.create!(player: players(:grace), preference: 'thumbs_up')

    travel_to(match_nights(:fall_upcoming).availability_cutoff_at + 1.minute) do
      get season_match_nights_path(seasons(:fall))
    end

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[type=radio]", count: 0
    assert_select "#{frame} span.bg-dpc-green .sr-only", text: 'Prefer', count: 1
    assert_select "#{frame} span.opacity-40 .sr-only", text: 'Prefer', count: 2
  end

  test 'keeps saved slot preferences when a player switches to out' do
    sign_in_as_ada
    slot = match_slots(:fall_future_slot_one)

    patch match_night_availability_path(match_nights(:fall_upcoming)), params: { match_availability: { status: 'out' } }

    assert_equal 'thumbs_up', slot.slot_availabilities.find_by!(player: players(:ada)).preference
  end

  test 'highlights only the saved answer when availability is closed for a non-captain' do
    sign_in_as(players(:grace))

    travel_to(match_nights(:fall_upcoming).availability_cutoff_at + 1.minute) do
      get season_match_nights_path(seasons(:fall))
    end

    frame = "##{dom_id(match_nights(:fall_upcoming), :my_availability)}"

    assert_select "#{frame} input[type=radio]", count: 0
    assert_select "#{frame} span.bg-red-700", text: 'Out'
    assert_select "#{frame} span.bg-dpc-green, #{frame} span.bg-amber-400", count: 0
  end

  test 'leaves every personal button unselected on a night the player has not answered' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_playoff), :my_availability)}"

    assert_select "#{frame} input[type=radio]", minimum: 3
    assert_select "#{frame} input[type=radio][checked]", count: 0
  end

  test 'team view shows ??? for players who have not answered and counts them separately' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} option[selected][disabled][value='']", text: '???', minimum: 1
    assert_select "#{frame} p", text: /\d+ in \u00b7 \d+ maybe \u00b7 [1-9]\d* \?\?\?/
  end

  test 'shows team availability for an admin' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall), view: 'availability')

    assert_select "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"
  end

  test 'disables the availability select for a team the captain does not control' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} select:not([disabled])", minimum: 1
    assert_select "#{frame} select[disabled]", minimum: 1
  end

  test 'team view shows each in player slot preferences in time order with ? for unanswered' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} li", text: /Ada.*7:00 PM: Prefer.*8:00 PM: Okay.*8:45 PM: No answer/m
    assert_select "#{frame} li span[aria-hidden]", text: '?', count: 1
  end

  test 'team view hides slot preferences for a player who is out' do
    sign_in_as_ada
    match_slots(:fall_future_slot_one).slot_availabilities.create!(player: players(:grace), preference: 'thumbs_up')

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(match_nights(:fall_upcoming), :team_availability)}"

    assert_select "#{frame} li", text: /Grace/ do |rows|
      assert_empty rows.first.css('.sr-only')
    end
  end

  test 'scopes the list to the requested season' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:spring))

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}", count: 0
  end

  test 'show renders the single night' do
    sign_in_as_ada

    get match_night_path(match_nights(:fall_week_one))

    assert_response :success
    assert_select "##{dom_id(match_nights(:fall_week_one))}"
  end

  test 'links a completed match to its scorecard for a plain player' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_week_one))} a[href=?][title=?]", match_path(matches(:fall_alpha_bravo)),
                  'Scorecard'
  end

  test 'does not nest team page links inside a scorecard link' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_week_one))} a[href=?]",
                  season_team_path(seasons(:fall).id, teams(:alpha)), count: 0
  end

  test 'links team names to the team page on an unplayed match for a plain player' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]",
                  season_team_path(seasons(:fall).id, teams(:bravo))
  end

  test 'shows an enter results link on an unplayed match for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?][title=?]", edit_match_path(matches(:fall_future)),
                  'Enter results'
  end

  test 'shows an enter results link on an unplayed match for an admin' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]", edit_match_path(matches(:fall_future))
  end

  test 'hides the enter results link from a captain once the match night is locked' do
    sign_in_as_ada
    night = match_nights(:fall_upcoming)

    travel_to(night.results_locked_at + 1.minute) { get season_match_nights_path(seasons(:fall)) }

    assert_select "##{dom_id(night)} a[href=?]", edit_match_path(matches(:fall_future)), count: 0
  end

  test 'keeps the enter results link for an admin once the match night is locked' do
    sign_in_as(players(:zoe))
    night = match_nights(:fall_upcoming)

    travel_to(night.results_locked_at + 1.minute) { get season_match_nights_path(seasons(:fall)) }

    assert_select "##{dom_id(night)} a[href=?]", edit_match_path(matches(:fall_future))
  end

  test 'hides the enter results link from a plain player' do
    sign_in_as(players(:grace))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]", edit_match_path(matches(:fall_future)),
                  count: 0
  end

  test 'links a completed match to its scorecard rather than the edit form for a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    frame = "##{dom_id(match_nights(:fall_week_one))}"

    assert_select "#{frame} a[href=?]", match_path(matches(:fall_alpha_bravo))
    assert_select "#{frame} a[href=?]", edit_match_path(matches(:fall_alpha_bravo)), count: 0
  end

  test 'links an admin to add and edit nights without cancel buttons' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select 'a[href=?]', new_admin_match_night_path(season: seasons(:fall))
    assert_select "##{dom_id(match_nights(:fall_upcoming))} a[href=?]",
                  edit_admin_match_night_path(match_nights(:fall_upcoming))
    assert_select 'button', text: 'Cancel night', count: 0
  end

  test 'hides the availability control on a canceled night' do
    sign_in_as(players(:zoe))

    get season_match_nights_path(seasons(:fall))

    assert_select "##{dom_id(match_nights(:fall_canceled), :my_availability)}", count: 0
  end

  test 'hides the add and edit night links from a captain' do
    sign_in_as_ada

    get season_match_nights_path(seasons(:fall))

    assert_select 'a[href=?]', new_admin_match_night_path(season: seasons(:fall)), count: 0
    assert_select 'a[href=?]', edit_admin_match_night_path(match_nights(:fall_upcoming)), count: 0
  end

  test 'treats a player deactivated mid-session as signed out' do
    sign_in_as_ada
    players(:ada).inactive!

    get season_match_nights_path(seasons(:fall))

    assert_redirected_to root_path
  end

  test 'index query count does not grow with more match nights' do
    sign_in_as_ada
    season = seasons(:fall)

    before = count_queries { get season_match_nights_path(season) }
    add_match_nights(season)
    after = count_queries { get season_match_nights_path(season) }

    assert_equal before, after
  end

  test 'team availability query count does not grow with more match nights' do
    sign_in_as_ada
    season = seasons(:fall)

    before = count_queries { get season_match_nights_path(season, view: 'availability') }
    add_match_nights(season)
    after = count_queries { get season_match_nights_path(season, view: 'availability') }

    assert_equal before, after
  end

  test 'past team availability shows results without selection controls' do
    sign_in_as_ada

    travel_to Time.zone.local(2026, 9, 24) do
      get season_match_nights_path(seasons(:fall), view: 'availability')
    end

    frame = "##{dom_id(match_nights(:fall_week_one))}"

    assert_select "#{frame} select", count: 0
    assert_select "#{frame} a[href=?]", match_path(matches(:fall_alpha_bravo))
  end

  test 'team availability colors saved responses and unanswered choices' do
    sign_in_as(players(:zoe))
    night = match_nights(:fall_upcoming)
    night.match_availabilities.create!(player: players(:sam), status: 'out')
    night.match_availabilities.create!(player: players(:ben), status: 'maybe')
    night.match_availabilities.where(player: players(:grace)).destroy_all

    get season_match_nights_path(seasons(:fall), view: 'availability')

    frame = "##{dom_id(night, :team_availability)}"

    assert_select "#{frame} select.bg-dpc-green option[selected][value=in]"
    assert_select "#{frame} select.bg-red-700 option[selected][value=out]"
    assert_select "#{frame} select.bg-amber-400 option[selected][value=maybe]"
    assert_select "#{frame} select.bg-white option[selected][value='']"
  end

  private

  def add_match_nights(season)
    3.times { |n| season.match_nights.create!(played_on: Date.current + 30 + n, label: "Extra #{n}") }
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  def sign_in_as_ada
    sign_in_as(players(:ada))
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
