# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_23_020002) do
  create_table "games", force: :cascade do |t|
    t.integer "away_score", null: false
    t.datetime "created_at", null: false
    t.integer "home_score", null: false
    t.integer "lineup_id", null: false
    t.integer "number", null: false
    t.datetime "updated_at", null: false
    t.index ["lineup_id", "number"], name: "index_games_on_lineup_id_and_number", unique: true
  end

  create_table "lineups", force: :cascade do |t|
    t.integer "away_player_one_id", null: false
    t.integer "away_player_two_id", null: false
    t.datetime "created_at", null: false
    t.integer "home_player_one_id", null: false
    t.integer "home_player_two_id", null: false
    t.integer "match_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["away_player_one_id"], name: "index_lineups_on_away_player_one_id"
    t.index ["away_player_two_id"], name: "index_lineups_on_away_player_two_id"
    t.index ["home_player_one_id"], name: "index_lineups_on_home_player_one_id"
    t.index ["home_player_two_id"], name: "index_lineups_on_home_player_two_id"
    t.index ["match_id", "position"], name: "index_lineups_on_match_id_and_position", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.integer "away_match_points", default: 0, null: false
    t.integer "away_points_scored", default: 0, null: false
    t.integer "away_team_id", null: false
    t.datetime "created_at", null: false
    t.integer "home_match_points", default: 0, null: false
    t.integer "home_points_scored", default: 0, null: false
    t.integer "home_team_id", null: false
    t.date "played_on"
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
    t.index ["season_id", "played_on"], name: "index_matches_on_season_id_and_played_on"
  end

  create_table "players", force: :cascade do |t|
    t.string "avatar_url", limit: 512
    t.datetime "created_at", null: false
    t.string "email", limit: 255
    t.string "first_name", limit: 100, null: false
    t.string "google_uid", limit: 255
    t.string "last_name", limit: 100, null: false
    t.datetime "last_signed_in_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_players_on_email", unique: true
    t.index ["google_uid"], name: "index_players_on_google_uid", unique: true
  end

  create_table "roster_spots", force: :cascade do |t|
    t.boolean "captain", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "season_id", null: false
    t.integer "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_roster_spots_on_player_id"
    t.index ["season_id", "player_id"], name: "index_roster_spots_on_season_and_player", unique: true
    t.index ["season_id", "team_id"], name: "index_roster_spots_on_season_id_and_team_id"
    t.index ["team_id"], name: "index_roster_spots_on_team_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.string "name", limit: 100, null: false
    t.date "starts_on"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_seasons_on_name", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.string "tagline", limit: 200
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  add_foreign_key "games", "lineups"
  add_foreign_key "lineups", "matches"
  add_foreign_key "lineups", "players", column: "away_player_one_id"
  add_foreign_key "lineups", "players", column: "away_player_two_id"
  add_foreign_key "lineups", "players", column: "home_player_one_id"
  add_foreign_key "lineups", "players", column: "home_player_two_id"
  add_foreign_key "matches", "seasons"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "roster_spots", "players"
  add_foreign_key "roster_spots", "seasons"
  add_foreign_key "roster_spots", "teams"
end
