require 'test_helper'

class MatchupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @season = seasons(:scorecard)
    @match = matches(:scorecard_match)
    travel_to Date.new(2026, 1, 5)
  end

  test 'signed-out visitors are redirected' do
    get season_matchup_path(@season)

    assert_redirected_to root_path
  end

  test 'regular players are redirected' do
    sign_in_as players(:sc_home_player1)

    get season_matchup_path(@season)

    assert_redirected_to root_path
  end

  test 'captain sees own team lines with ratings columns' do
    LineupPick.create!(match: @match, team: teams(:sc_home), player: players(:sc_home_player1), position: 1, seat: 1)
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_response :success
    assert_select 'th', text: 'PUPR'
    assert_select 'td', text: 'Line 1', minimum: 2
    assert_select 'td', text: players(:sc_home_player1).full_name
  end

  test 'move buttons show while editable and disappear once a lineup is recorded' do
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'button[data-role=move]', minimum: 1

    @match.lineups.create!(position: 1)
    get season_matchup_path(@season)

    assert_select 'button[data-role=move]', count: 0
  end

  test 'rows are marked complete, incomplete, or bench' do
    home = teams(:sc_home)
    LineupPick.create!(match: @match, team: home, player: players(:sc_home_player1), position: 1, seat: 1)
    LineupPick.create!(match: @match, team: home, player: players(:sc_home_player2), position: 2, seat: 1)
    LineupPick.create!(match: @match, team: home, player: players(:sc_home_player3), position: 2, seat: 2)
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'tr[data-state=incomplete]', minimum: 1
    assert_select 'tr[data-state=complete]', minimum: 1
    assert_select 'tr[data-state=bench]', minimum: 1
  end

  test 'subs endpoint lazily returns eligible unrostered players' do
    free = Player.create!(first_name: 'Free', last_name: 'Agent', calendar_token: SecureRandom.hex(16))
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select "tr[data-sub-id='#{free.id}']", count: 0

    get match_team_subs_path(@match, teams(:sc_home))

    assert_response :success
    assert_select "tr[data-sub-source][data-sub-id='#{free.id}']"
  end

  test 'subs endpoint is closed to other teams captains' do
    sign_in_as players(:sc_away_captain)

    get match_team_subs_path(@match, teams(:sc_home))

    assert_redirected_to match_path(@match)
  end

  test 'the optional third seat is rendered hidden until used' do
    LineupPick.create!(match: @match, team: teams(:sc_home), player: players(:sc_home_player1), position: 1, seat: 1)
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'tr[data-extra][hidden]', minimum: 1
  end

  test 'availability chips show on players who answered' do
    pick = players(:sc_home_player1)
    LineupPick.create!(match: @match, team: teams(:sc_home), player: pick, position: 1, seat: 1)
    MatchAvailability.create!(match_night: @match.match_night, player: pick, status: 'out')
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'td[data-slot=name] span', text: 'Out'
  end

  test 'captain sees the opponent panel with their planned players' do
    away = teams(:sc_away)
    LineupPick.create!(match: @match, team: away, player: players(:sc_away_player1), position: 1, seat: 1)
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'h2', text: away.name
    assert_select 'td[data-slot=name]', text: /#{players(:sc_away_player1).full_name}/
  end

  test 'scoreboard shows both teams and a money line for each' do
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select '[data-odds=mine]'
    assert_select '[data-odds=theirs]'
  end

  test 'the season dropdown has no all-time entry' do
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season)

    assert_select 'a', text: 'All time', count: 0
  end

  test 'captain cannot view another team' do
    sign_in_as players(:sc_home_captain)

    get season_matchup_path(@season, team_id: teams(:sc_away).id)

    assert_select 'p', text: /#{teams(:sc_home).name} vs/
  end

  test 'admin can pick any team' do
    sign_in_as players(:zoe)

    get season_matchup_path(@season, team_id: teams(:sc_away).id)

    assert_select 'p', text: /#{teams(:sc_away).name} vs/
  end

  private

  def sign_in_as(player)
    mock_google_auth(email: player.email, uid: player.google_uid)
    post '/auth/google_oauth2'
    follow_redirect!
  end
end
