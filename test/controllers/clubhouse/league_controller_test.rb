require 'test_helper'

module Clubhouse
  class LeagueControllerTest < ActionDispatch::IntegrationTest
    setup do
      @captain = Player.create!(first_name: 'Chris', last_name: 'Bell', email: 'captain@example.test')
      @data = { 'id' => 'fall-2026', 'name' => 'Fall 2026', 'teams' => %w[A B],
                'weeks' => [{ 'id' => 1, 'label' => 'Week 1', 'date' => '2026-09-24' },
                            { 'id' => 2, 'label' => 'Final', 'date' => '2026-09-24' }],
                'players' => [players(:ada), @captain].each_with_index.map do |p, i|
                  { 'id' => i.to_s, 'name' => p.full_name, 'email' => p.email,
                    'phone' => '555-0100', 'rank' => '1A', 'team' => 'A', 'paid' => true, 'availability' => {} }
                end,
                'matches' => [], 'announcements' => [], 'rules' => 'League rules', 'fee' => 50 }
      @season = Import.create!(@data, current: true)
    end

    test 'signed out callers cannot read private league data' do
      get '/clubhouse/api/league'

      assert_response :unauthorized
    end

    test 'member response omits other contacts ranks account ids and payment status' do
      sign_in_as(players(:ada))
      get '/clubhouse/api/league'

      assert_response :success
      response.parsed_body.values_at('season', 'lifetimePlayers').then do |season, career|
        rows = season['players'] + career

        assert(rows.none? { |p| p.key?('rank') || p.key?('accountId') || p.key?('elo') })
        other = season['players'].find { |p| p['id'] == '1' }

        assert_empty other.keys & %w[email contactEmail phone paid availability]
      end
    end

    test 'member can change only personal availability and date-linked rounds' do
      sign_in_as(players(:ada))
      change('availability', playerId: '1', week: 1, value: 'yes')

      assert_response :unprocessable_entity
      change('availability', playerId: '0', week: 1, value: 'yes')

      assert_response :success
      assert_equal({ '1' => 'yes', '2' => 'yes' }, @season.reload.payload['players'][0]['availability'])
    end

    test 'member cannot enter results or change team availability or payment' do
      sign_in_as(players(:ada))
      %w[result teamAvailability payment].each do |action|
        change(action, playerId: '1', week: 1, value: 'yes')

        assert_response :forbidden
      end
    end

    test 'captain sees ranks and can set any roster availability' do
      sign_in_as(@captain)
      get '/clubhouse/api/league'

      assert response.parsed_body['captain']
      assert_equal '1A', response.parsed_body['season']['players'][0]['rank']
      change('teamAvailability', playerId: '0', week: 1, value: 'no')

      assert_response :success
      change('payment', playerId: '0', paid: false)

      assert_response :forbidden
    end

    test 'stale writes and archive writes are rejected' do
      sign_in_as(players(:ada))
      change('availability', playerId: '0', week: 1, value: 'yes', revision: 10)

      assert_response :conflict
      @season.update!(payload: @season.payload.merge('archived' => true))
      change('availability', playerId: '0', week: 1, value: 'yes')

      assert_response :forbidden
    end

    test 'forged captain flag in import cannot grant access' do
      @data['players'][0]['captain'] = true
      @data['players'][0]['accountId'] = @captain.id
      prepared = Import.prepare(@data)

      assert_equal players(:ada).id, prepared['players'][0]['accountId']
      assert_not_predicate Access.new(players(:ada), prepared), :captain?
    end

    test 'photo upload and original bytes require member access' do
      sign_in_as(players(:ada))
      photo = ClubhousePhoto.create!(player: @captain, content_type: 'image/png', image_data: 'test', caption: 'Court')
      delete '/clubhouse/api/photos', params: { id: photo.id }

      assert_response :forbidden
      delete sign_out_path
      get '/clubhouse/api/photos', params: { image: photo.id }

      assert_response :unauthorized
    end

    test 'captain can post a complete scorecard but cannot post tied games' do
      extra = %w[Third Fourth].map.with_index do |name, i|
        { 'id' => "extra-#{i}", 'name' => "#{name} Player", 'team' => 'B' }
      end
      payload = @season.payload.deep_dup
      payload['players'].concat(extra)
      names = payload['players'].pluck('name')
      lines = (1..5).map do |number|
        { 'line' => number, 'a' => [names[0], names[1], ''],
          'b' => [names[2], names[3], ''], 'scores' => [[11, 5], [11, 5], [11, 5]] }
      end
      payload['matches'] = [{ 'id' => 'match', 'week' => 1, 'a' => 'A', 'b' => 'B', 'lines' => lines }]
      @season.update!(payload: payload)
      sign_in_as(@captain)
      change('result', matchId: 'match', lines: lines)

      assert_response :success
      assert_equal lines, @season.reload.payload['matches'][0]['lines']
      lines[0]['scores'][0] = [11, 11]
      change('result', matchId: 'match', lines: lines)

      assert_response :unprocessable_content
    end

    test 'an inactive account cannot retain access through an existing session' do
      sign_in_as(players(:ada))
      players(:ada).update!(status: 'inactive')
      get '/clubhouse/api/league'

      assert_response :unauthorized
    end

    test 'an ordinary member cannot change another profile or captain role' do
      sign_in_as(players(:ada))
      change('profile', playerId: '1', phone: '555-9999')

      assert_response :unprocessable_content
      change('profile', playerId: '0', captain: true)

      assert_response :unprocessable_content
    end

    private

    def sign_in_as(player)
      mock_google_auth(email: player.email, uid: player.google_uid || "test-#{player.id}")
      post '/auth/google_oauth2'
      follow_redirect!
    end

    def change(action, **attributes)
      post '/clubhouse/api/league',
           params: { action: action, seasonId: 'fall-2026',
                     revision: @season.lock_version }.merge(attributes), as: :json
    end
  end
end
