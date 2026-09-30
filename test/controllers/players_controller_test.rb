require 'test_helper'

class PlayersControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  CONTACT_HIDDEN = 'Contact details are available to captains.'.freeze
  CONTACT_HIDDEN_PATTERN = /#{Regexp.escape(CONTACT_HIDDEN)}/

  test 'signed out visitors are redirected' do
    get players_path

    assert_redirected_to root_path

    get player_path(players(:sam))

    assert_redirected_to root_path

    get edit_player_path(players(:sam))

    assert_redirected_to root_path

    patch player_path(players(:sam)), params: { player: { phone: '1' } }

    assert_redirected_to root_path
    assert_equal '512-555-0101', players(:sam).reload.phone
  end

  test 'index lists the season roster as cards' do
    sign_in_as(players(:grace))

    get players_path

    assert_response :success
    %i[ada grace sam ben].each { |name| assert_select "##{dom_id(players(name), :card)}" }
    assert_select "##{dom_id(players(:ada), :card)}", text: /Captain/
    assert_select "##{dom_id(players(:ada), :card)}", text: /67%/
  end

  test 'a captain sees contact details on the directory' do
    sign_in_as(players(:ada))

    get players_path

    assert_select "##{dom_id(players(:sam), :card)}", text: /sam.contact@example.test/
    assert_select "##{dom_id(players(:sam), :card)}", text: /512-555-0101/
  end

  test 'an admin sees contact details on the directory' do
    sign_in_as(players(:zoe))

    get players_path

    assert_select "##{dom_id(players(:sam), :card)}", text: /sam.contact@example.test/
  end

  test 'a plain player sees the captains-only message instead of contact details' do
    sign_in_as(players(:grace))

    get players_path

    assert_select "##{dom_id(players(:sam), :card)}", text: CONTACT_HIDDEN_PATTERN
    assert_not_includes response.body, 'sam.contact@example.test'
    assert_not_includes response.body, '512-555-0101'
  end

  test 'contact visibility follows the viewed season' do
    sign_in_as(players(:sc_home_captain))

    get players_path(season: seasons(:fall).id)

    assert_not_includes response.body, 'sam.contact@example.test'
  end

  test 'search filters by name' do
    sign_in_as(players(:grace))

    get players_path(q: 'sAm')

    assert_select "##{dom_id(players(:sam), :card)}"
    assert_select "##{dom_id(players(:ada), :card)}", count: 0
  end

  test 'team filter limits to one team' do
    sign_in_as(players(:grace))

    get players_path(team: teams(:bravo).id)

    assert_select "##{dom_id(players(:sam), :card)}"
    assert_select "##{dom_id(players(:ada), :card)}", count: 0
  end

  test 'substitutes can be isolated or hidden' do
    sub = add_substitute
    sign_in_as(players(:grace))

    get players_path(team: 'substitutes')

    assert_select "##{dom_id(sub, :card)}", text: /Substitute/
    assert_select "##{dom_id(players(:ada), :card)}", count: 0

    get players_path(hide_substitutes: '1')

    assert_select "##{dom_id(sub, :card)}", count: 0
    assert_select "##{dom_id(players(:ada), :card)}"
  end

  test 'win rate sort puts the best first and players without games last' do
    bench = Player.create!(first_name: 'Aaron', last_name: 'Bench')
    RosterSpot.create!(season: seasons(:fall), team: teams(:alpha), player: bench)
    sign_in_as(players(:grace))

    get players_path(sort: 'win_pct')

    assert_operator card_index(players(:ada)), :<, card_index(players(:sam))
    assert_operator card_index(players(:sam)), :<, card_index(bench)
  end

  test 'team sort groups by team name with substitutes last' do
    sub = add_substitute
    sign_in_as(players(:grace))

    get players_path(sort: 'team')

    assert_operator card_index(players(:grace)), :<, card_index(players(:ben))
    assert_operator card_index(players(:ben)), :<, card_index(sub)
  end

  test 'name sort is the default' do
    sign_in_as(players(:grace))

    get players_path

    assert_operator card_index(players(:ada)), :<, card_index(players(:ben))
    assert_operator card_index(players(:ben)), :<, card_index(players(:grace))
  end

  test 'scopes the directory to the requested season' do
    sign_in_as(players(:grace))

    get players_path(season: seasons(:spring).id)

    assert_select "##{dom_id(players(:ada), :card)}"
    assert_select "##{dom_id(players(:sam), :card)}", count: 0
  end

  test 'profile shows this season line results' do
    sign_in_as(players(:grace))

    get player_path(players(:ada))

    assert_response :success
    assert_select 'h1', text: players(:ada).full_name
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /Line 1 vs Test Team Bravo/
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /11-4, 6-11, 12-10/
    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /With Grace Fixture/
  end

  test 'profile never exposes the calendar feed token, even on your own page' do
    sign_in_as(players(:ada))

    get player_path(players(:ada))

    assert_response :success
    assert_not_includes response.body, players(:ada).calendar_token
  end

  test 'profile shows scores from the away side for an away player' do
    sign_in_as(players(:grace))

    get player_path(players(:sam))

    assert_select "##{dom_id(lineups(:fall_alpha_bravo_one), :result)}", text: /4-11, 11-6, 10-12/
  end

  test 'profile contact details follow the same role rules' do
    sign_in_as(players(:grace))
    get player_path(players(:sam))

    assert_select 'p', text: CONTACT_HIDDEN
    assert_not_includes response.body, 'sam.contact@example.test'

    sign_in_as(players(:ada))
    get player_path(players(:sam))

    assert_includes response.body, 'sam.contact@example.test'

    sign_in_as(players(:zoe))
    get player_path(players(:sam))

    assert_includes response.body, 'sam.contact@example.test'
  end

  test 'a player can edit their own profile' do
    sign_in_as(players(:grace))

    get edit_player_path(players(:grace))

    assert_response :success
    assert_select 'input[name="player[contact_email]"]'
    assert_select 'input[name="player[email]"]', count: 0
  end

  test 'a player cannot edit another player profile' do
    sign_in_as(players(:grace))

    get edit_player_path(players(:sam))

    assert_redirected_to root_path

    patch player_path(players(:sam)), params: { player: { phone: '999' } }

    assert_redirected_to root_path
    assert_equal '512-555-0101', players(:sam).reload.phone
  end

  test 'a player updates their own phone and contact email but not the sign-in email' do
    sign_in_as(players(:grace))

    patch player_path(players(:grace)),
          params: { player: { phone: '512-555-0199', contact_email: 'grace.alt@example.test',
                              email: 'hijack@example.test' } }

    assert_redirected_to player_path(players(:grace))
    grace = players(:grace).reload

    assert_equal '512-555-0199', grace.phone
    assert_equal 'grace.alt@example.test', grace.contact_email
    assert_equal 'grace@example.test', grace.email
  end

  test 'an admin can edit any player profile' do
    sign_in_as(players(:zoe))

    get edit_player_path(players(:sam))

    assert_response :success

    patch player_path(players(:sam)), params: { player: { phone: '512-555-0000' } }

    assert_redirected_to player_path(players(:sam))
    assert_equal '512-555-0000', players(:sam).reload.phone
  end

  test 'an invalid contact email re-renders the form' do
    sign_in_as(players(:grace))

    patch player_path(players(:grace)), params: { player: { contact_email: 'not an email' } }

    assert_response :unprocessable_content
    assert_nil players(:grace).reload.contact_email
  end

  private

  def add_substitute
    sub = Player.create!(first_name: 'Zed', last_name: 'Sub')
    lineup = matches(:fall_alpha_bravo).lineups.create!(position: 2)
    lineup.games.create!(number: 1, home_score: 11, away_score: 3,
                         home_player_a: sub, home_player_b: players(:zoe),
                         away_player_a: players(:wade), away_player_b: players(:sc_home_player1))
    sub
  end

  def card_index(player)
    response.body.index(dom_id(player, :card))
  end

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: "mock-uid-#{player.id}")
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
