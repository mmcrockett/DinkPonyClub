require 'test_helper'

class PlayersControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  CONTACT_HIDDEN = 'Contact details are available to captains.'.freeze

  setup do
    @substitute = Player.create!(first_name: 'Sub', last_name: 'Stitute')
    @bench = Player.create!(first_name: 'Bench', last_name: 'Warmer')
    RosterSpot.create!(season: seasons(:fall), team: teams(:bravo), player: @bench)
    add_sub_line
  end

  test 'signed out visitors are redirected' do
    get season_players_path(seasons(:fall))

    assert_redirected_to root_path

    get season_player_path(seasons(:fall), players(:sam))

    assert_redirected_to root_path
  end

  test 'lists rostered players and substitutes' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_response :success
    %i[ada grace sam ben].each { |name| assert_select "##{dom_id(players(name), :stats)}" }
    assert_select "##{dom_id(@substitute, :stats)}", text: /Substitute/
  end

  test 'admins see who owes money' do
    sign_in_as(players(:zoe))

    get season_players_path(seasons(:fall))

    assert_select "##{dom_id(players(:ada), :stats)} .owes-chip"
    assert_select "##{dom_id(players(:grace), :stats)} .owes-chip", count: 0
  end

  test 'captains see who owes money' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select "##{dom_id(players(:ada), :stats)} .owes-chip"
  end

  test 'regular players do not see who owes money' do
    sign_in_as(players(:grace))

    get season_players_path(seasons(:fall))

    assert_select '.owes-chip', count: 0
  end

  test 'links each name to the player profile' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    profile = season_player_path(seasons(:fall), players(:grace))

    assert_select "##{dom_id(players(:grace), :stats)} a[href='#{profile}']", text: players(:grace).full_name
  end

  test 'shows a dash for a player with no games' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select "##{dom_id(@bench, :stats)} td", text: '-'
  end

  test 'shows win pct' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select "##{dom_id(@substitute, :stats)} td", text: '100%'
  end

  test 'omits per-player sweep bonus and points columns' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select 'th', text: 'Sweep bonus', count: 0
    assert_select 'th', text: 'Points', count: 0
  end

  test 'filters submit on change with no apply button' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select 'form[data-controller="auto-submit"] input[type=submit]', count: 0
    assert_select 'input[name=q][data-action="input->auto-submit#debouncedSubmit"]'
    assert_select 'select[name=sort]', count: 0
  end

  test 'shows the C chip only for captains' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select "##{dom_id(players(:ada), :stats)} .captain-chip", text: 'C'
    assert_select "##{dom_id(players(:grace), :stats)} .captain-chip", count: 0
    assert_select '.captain-chip', count: RosterSpot.where(season: seasons(:fall), captain: true).count
  end

  test 'searches by name' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), q: 'grace')

    assert_select 'tbody tr', count: 1
    assert_select "##{dom_id(players(:grace), :stats)}"
  end

  test 'filters by team' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), team: teams(:bravo).id)

    assert_equal ids(players(:ben), @bench, players(:sam)).sort, row_ids.sort
  end

  test 'filters to substitutes' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), team: 'substitutes')

    assert_equal ids(@substitute), row_ids
  end

  test 'hides substitutes' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), hide_substitutes: '1')

    assert_select "##{dom_id(@substitute, :stats)}", count: 0
    assert_select "##{dom_id(players(:ada), :stats)}"
  end

  test 'shows a message when filters match nobody' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), q: 'nobody')

    assert_select 'table', count: 0
    assert_select 'p', text: 'No players match these filters.'
  end

  test 'sorts by name by default' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_equal ids(players(:ada), players(:ben), @bench, players(:grace), players(:sam), @substitute), row_ids
  end

  test 'sorts by name descending' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'name', dir: 'desc')

    assert_equal ids(@substitute, players(:sam), players(:grace), @bench, players(:ben), players(:ada)), row_ids
  end

  test 'sorts by win pct descending with zero-game players last' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'win_pct', dir: 'desc')

    assert_equal ids(@substitute, players(:ben), players(:ada), players(:grace), players(:sam), @bench), row_ids
  end

  test 'sorts by win pct ascending with zero-game players last' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'win_pct', dir: 'asc')

    assert_equal ids(players(:ada), players(:grace), players(:sam), players(:ben), @substitute, @bench), row_ids
  end

  test 'sorts by team with substitutes last' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'team')

    assert_equal ids(players(:ada), players(:grace), players(:ben), @bench, players(:sam), @substitute), row_ids
  end

  test 'sorts by games with most games first by default' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'games')

    assert_equal ids(players(:ada), players(:ben), players(:grace), players(:sam), @substitute, @bench), row_ids
  end

  test 'header links sort by that column and reverse the active one' do
    sign_in_as(players(:ada))

    fall = seasons(:fall)
    get season_players_path(fall, q: 'a', sort: 'win_pct', dir: 'desc')

    assert_select "th[aria-sort=descending] a[href='#{season_players_path(fall, q: 'a', sort: 'win_pct', dir: 'asc')}']"
    assert_select "th[aria-sort=none] a[href='#{season_players_path(fall, q: 'a', sort: 'wins', dir: 'desc')}']"
    assert_select "th[aria-sort=none] a[href='#{season_players_path(fall, q: 'a', sort: 'name', dir: 'asc')}']"
  end

  test 'filters keep the current sort' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall), sort: 'wins', dir: 'asc')

    assert_select 'input[type=hidden][name=sort][value=wins]'
    assert_select 'input[type=hidden][name=dir][value=asc]'
  end

  test 'scopes to the requested season' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:spring))

    assert_equal ids(players(:ada)), row_ids
  end

  test 'shows an empty state for a season with no roster' do
    season = Season.create!(name: 'Winter 2027', starts_on: Date.new(2027, 1, 4))
    sign_in_as(players(:ada))

    get season_players_path(season)

    assert_response :success
    assert_select 'p', text: 'No players are rostered for this season yet.'
  end

  test 'sidebar has one Players entry and no Stats entry' do
    sign_in_as(players(:ada))

    get season_players_path(seasons(:fall))

    assert_select "aside a[href='#{season_players_path(seasons(:fall))}']", text: /Players/, count: 1
    assert_select 'aside a', text: /Stats/, count: 0
  end

  test 'profile edit no longer routes' do
    sign_in_as(players(:zoe))

    get "/players/#{players(:sam).id}/edit"

    assert_response :not_found

    patch "/players/#{players(:sam).id}", params: { player: { phone: '1' } }

    assert_response :not_found
    assert_equal '512-555-0101', players(:sam).reload.phone
  end

  test 'profile shows this season line results' do
    sign_in_as(players(:grace))

    get season_player_path(seasons(:fall), players(:ada))

    assert_response :success
    assert_select 'h1', text: players(:ada).full_name
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /Line 1 vs Test Team Bravo/
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /11-4, 6-11, 12-10/
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /With Grace Fixture/
  end

  test 'profile lists every season with a career total and highlights the viewed one' do
    sign_in_as(players(:grace))

    get season_player_path(seasons(:fall), players(:ada))

    assert_select '.career tbody tr', count: 2
    assert_select ".career a[href='#{season_player_path(seasons(:spring), players(:ada))}']",
                  text: seasons(:spring).name
    assert_select ".career tr##{dom_id(seasons(:fall), :career)}.font-bold"
    assert_select '.career-total', text: /Career\s+6\s+2\s+4\s+33%/
  end

  test 'profile never exposes the calendar feed token, even on your own page' do
    sign_in_as(players(:ada))

    get season_player_path(seasons(:fall), players(:ada))

    assert_response :success
    assert_not_includes response.body, players(:ada).calendar_token
  end

  test 'profile shows scores from the away side for an away player' do
    sign_in_as(players(:grace))

    get season_player_path(seasons(:fall), players(:sam))

    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /4-11, 11-6, 10-12/
  end

  test 'profile has no edit link' do
    sign_in_as(players(:grace))

    get season_player_path(seasons(:fall), players(:grace))

    assert_select 'a', text: 'Edit profile', count: 0
  end

  test 'a plain player sees the captains-only message instead of contact details' do
    sign_in_as(players(:grace))

    get season_player_path(seasons(:fall), players(:sam))

    assert_select 'p', text: CONTACT_HIDDEN
    assert_not_includes response.body, 'sam@example.test'
    assert_not_includes response.body, '512-555-0101'
  end

  test 'a captain sees the sign-in email and phone on the profile' do
    sign_in_as(players(:ada))

    get season_player_path(seasons(:fall), players(:sam))

    assert_select "a[href='mailto:sam@example.test']"
    assert_select "a[href='tel:512-555-0101']"
  end

  test 'an admin sees the sign-in email and phone on the profile' do
    sign_in_as(players(:zoe))

    get season_player_path(seasons(:fall), players(:sam))

    assert_select "a[href='mailto:sam@example.test']"
    assert_select "a[href='tel:512-555-0101']"
  end

  test 'the profile ignores the legacy contact email' do
    players(:sam).update!(contact_email: 'legacy@example.test')
    sign_in_as(players(:ada))

    get season_player_path(seasons(:fall), players(:sam))

    assert_not_includes response.body, 'legacy@example.test'
  end

  test 'contact visibility follows the viewed season' do
    sign_in_as(players(:sc_home_captain))

    get season_player_path(seasons(:fall), players(:sam))

    assert_not_includes response.body, 'sam@example.test'
  end

  private

  def add_sub_line
    match = Match.create!(season: seasons(:fall), match_night: match_nights(:fall_week_one),
                          home_team: teams(:bravo), away_team: teams(:alpha))
    lineup = match.lineups.create!(position: 2)
    3.times do |index|
      lineup.games.create!(number: index + 1, home_score: 11, away_score: 3,
                           home_player_a: @substitute, home_player_b: players(:ben),
                           away_player_a: players(:grace), away_player_b: players(:ada))
    end
  end

  def ids(*players)
    players.map { |player| dom_id(player, :stats) }
  end

  def row_ids
    css_select('tbody tr').pluck('id')
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: "mock-uid-#{player.id}")
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
