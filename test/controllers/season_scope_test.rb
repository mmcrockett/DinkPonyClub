require 'test_helper'

class SeasonScopeTest < ActionDispatch::IntegrationTest
  HOSTILE_QUERY = 'action=index&controller=admin%2Fplayers&script_name=%2F%2Fevil.example'.freeze

  setup do
    mock_google_auth(email: players(:ada).email)
    post '/auth/google_oauth2'
    follow_redirect!
  end

  test 'legacy standings url redirects to the default season' do
    get standings_path

    assert_redirected_to season_standings_path(seasons(:fall))
  end

  test 'legacy season param picks the season and other params survive' do
    get players_path(season: seasons(:spring).id, q: 'ada')

    assert_redirected_to season_players_path(seasons(:spring), q: 'ada')
  end

  test 'legacy schedule and player urls redirect' do
    get match_nights_path

    assert_redirected_to season_match_nights_path(seasons(:fall))

    get player_path(players(:ada))

    assert_redirected_to season_player_path(seasons(:fall), players(:ada))
  end

  test 'an unknown season is a 404' do
    get '/seasons/0-nope/standings'

    assert_response :not_found
  end

  test 'a slugged season url resolves by id' do
    get "/seasons/#{seasons(:spring).id}-whatever/standings"

    assert_response :success
    assert_select 'nav[aria-label=Breadcrumb] summary', text: /Spring 2026/
  end

  test 'breadcrumb lists every season and keeps the page and query' do
    get season_players_path(seasons(:fall), q: 'a', team: teams(:alpha).id)

    assert_select 'nav[aria-label=Breadcrumb] li a', count: Season.count
    assert_select "nav[aria-label=Breadcrumb] a[href='#{season_players_path(seasons(:spring), q: 'a')}']",
                  text: 'Spring 2026'
    assert_select 'nav[aria-label=Breadcrumb] a[aria-current=true]', text: 'Fall 2026'
  end

  test 'url-building params in the query stay in the query string' do
    get "#{season_standings_path(seasons(:fall))}?#{HOSTILE_QUERY}"

    assert_response :success
    assert_select 'nav[aria-label=Breadcrumb] li a' do |links|
      assert(links.all? { |link| link['href'].start_with?('/seasons/') })
    end
    assert_select "nav[aria-label=Breadcrumb] a[href*='script_name=%2F%2Fevil.example']", count: Season.count
  end

  test 'legacy redirect keeps hostile params in the query string' do
    get "#{standings_path}?#{HOSTILE_QUERY}"

    assert_redirected_to "#{season_standings_path(seasons(:fall))}?#{HOSTILE_QUERY}"
  end

  test 'sidebar links follow the season being browsed' do
    get season_standings_path(seasons(:spring))

    assert_select "aside a[href='#{season_players_path(seasons(:spring))}']"
    assert_select "aside a[href='#{season_match_nights_path(seasons(:spring))}']"
    assert_select "aside a[href='#{season_standings_path(seasons(:spring))}']"
  end
end
