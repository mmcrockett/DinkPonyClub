return if Season.exists?(name: 'Playoff Demo')

TEAM_NAMES = %w[Aces Bandits Comets Dingers].freeze
WEEKS = [
  [[0, 3, 0], [1, 2, 1]],
  [[0, 2, 1], [3, 1, 0]],
  [[0, 1, 2], [2, 3, 0]]
].freeze

season = Season.create!(name: 'Playoff Demo', starts_on: 1.month.ago.to_date, ends_on: 1.month.from_now.to_date,
                        lines_per_match: 2)
teams = TEAM_NAMES.map { |name| Team.create!(name: "Demo #{name}") }
rosters = teams.each_with_index.to_h do |team, t|
  players = Array.new(4) do |i|
    Player.create!(first_name: TEAM_NAMES[t], last_name: "Player#{i + 1}",
                   email: "#{TEAM_NAMES[t].downcase}#{i + 1}@example.com")
  end
  players.each_with_index { |player, i| RosterSpot.create!(season: season, team: team, player: player, captain: i.zero?) }
  [team, players]
end

Player.create!(first_name: 'Demo', last_name: 'Admin', email: 'admin@example.com', admin: true)

def score!(match, rosters, games_lost)
  home = rosters[match.home_team]
  away = rosters[match.away_team]
  match.line_positions.each do |position|
    lineup = match.lineups.create!(position: position)
    pair = [(position - 1) * 2, ((position - 1) * 2) + 1]
    3.times do |n|
      flipped = position == 2 && n >= 3 - games_lost
      lineup.games.create!(number: n + 1, home_score: flipped ? 7 : 11, away_score: flipped ? 11 : 6,
                           home_player_a: home[pair[0]], home_player_b: home[pair[1]],
                           away_player_a: away[pair[0]], away_player_b: away[pair[1]])
    end
  end
end

WEEKS.each_with_index do |pairings, week|
  night = season.match_nights.create!(played_on: (4 - week).weeks.ago.to_date, label: "Week #{week + 1}",
                                      venue: 'Demo Courts')
  pairings.each do |home, away, games_lost|
    match = night.matches.create!(season: season, home_team: teams[home], away_team: teams[away])
    score!(match, rosters, games_lost)
  end
end

playoff = season.match_nights.create!(played_on: Date.current, label: 'Playoffs', venue: 'Demo Courts', playoff: true)
[18, 19].each_with_index do |hour, index|
  today = Date.current
  playoff.match_slots.create!(position: index + 1, starts_at: Time.zone.local(today.year, today.month, today.day, hour))
end
