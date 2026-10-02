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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_220929) do
  create_table "charges", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.integer "fee_id", null: false
    t.integer "paid_cents", default: 0, null: false
    t.integer "roster_spot_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_id"], name: "index_charges_on_fee_id"
    t.index ["roster_spot_id", "fee_id"], name: "index_charges_on_roster_spot_id_and_fee_id", unique: true
    t.index ["roster_spot_id"], name: "index_charges_on_roster_spot_id"
  end

  create_table "fees", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.boolean "applies_to_all", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "name"], name: "index_fees_on_season_id_and_name", unique: true
    t.index ["season_id"], name: "index_fees_on_season_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "away_player_a_id", null: false
    t.integer "away_player_b_id", null: false
    t.integer "away_score", null: false
    t.datetime "created_at", null: false
    t.integer "home_player_a_id", null: false
    t.integer "home_player_b_id", null: false
    t.integer "home_score", null: false
    t.integer "lineup_id", null: false
    t.integer "number", null: false
    t.datetime "updated_at", null: false
    t.index ["away_player_a_id"], name: "index_games_on_away_player_a_id"
    t.index ["away_player_b_id"], name: "index_games_on_away_player_b_id"
    t.index ["home_player_a_id"], name: "index_games_on_home_player_a_id"
    t.index ["home_player_b_id"], name: "index_games_on_home_player_b_id"
    t.index ["lineup_id", "number"], name: "index_games_on_lineup_id_and_number", unique: true
  end

  create_table "lineups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id", "position"], name: "index_lineups_on_match_id_and_position", unique: true
  end

  create_table "match_availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_night_id", null: false
    t.integer "player_id", null: false
    t.string "status", limit: 10, default: "maybe", null: false
    t.datetime "updated_at", null: false
    t.index ["match_night_id", "player_id"], name: "index_match_availabilities_on_match_night_and_player", unique: true
    t.index ["player_id"], name: "index_match_availabilities_on_player_id"
  end

  create_table "match_nights", force: :cascade do |t|
    t.boolean "canceled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "label", limit: 60, null: false
    t.text "notes"
    t.date "played_on", null: false
    t.boolean "playoff", default: false, null: false
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.string "venue", limit: 150
    t.index ["season_id", "played_on"], name: "index_match_nights_on_season_id_and_played_on"
  end

  create_table "match_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_night_id", null: false
    t.integer "position", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_night_id", "position"], name: "index_match_slots_on_match_night_and_position", unique: true
    t.index ["match_night_id", "starts_at"], name: "index_match_slots_on_match_night_and_starts_at", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.integer "away_team_id", null: false
    t.datetime "created_at", null: false
    t.integer "home_team_id", null: false
    t.integer "match_night_id", null: false
    t.integer "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
    t.index ["season_id"], name: "index_matches_on_season_id"
  end

  create_table "players", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "avatar_url", limit: 512
    t.string "calendar_token", limit: 64, null: false
    t.string "contact_email", limit: 254
    t.datetime "created_at", null: false
    t.string "email", limit: 255
    t.string "first_name", limit: 100, null: false
    t.string "google_uid", limit: 255
    t.string "last_name", limit: 100, null: false
    t.datetime "last_signed_in_at"
    t.string "phone", limit: 40
    t.string "status", limit: 20, default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_token"], name: "index_players_on_calendar_token", unique: true
    t.index ["email"], name: "index_players_on_email", unique: true
    t.index ["google_uid"], name: "index_players_on_google_uid", unique: true
  end

  create_table "roster_spots", force: :cascade do |t|
    t.boolean "captain", default: false, null: false
    t.datetime "created_at", null: false
    t.string "draft_rank", limit: 10
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
    t.text "rules"
    t.date "starts_on"
    t.decimal "sweep_bonus", precision: 3, scale: 1, default: "0.5", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_seasons_on_name", unique: true
  end

  create_table "slot_availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "match_slot_id", null: false
    t.integer "player_id", null: false
    t.string "preference", limit: 20, default: "meh", null: false
    t.datetime "updated_at", null: false
    t.index ["match_slot_id", "player_id"], name: "index_slot_availabilities_on_slot_and_player", unique: true
    t.index ["player_id"], name: "index_slot_availabilities_on_player_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.string "tagline", limit: 200
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  add_foreign_key "charges", "fees"
  add_foreign_key "charges", "roster_spots"
  add_foreign_key "fees", "seasons"
  add_foreign_key "games", "lineups"
  add_foreign_key "games", "players", column: "away_player_a_id"
  add_foreign_key "games", "players", column: "away_player_b_id"
  add_foreign_key "games", "players", column: "home_player_a_id"
  add_foreign_key "games", "players", column: "home_player_b_id"
  add_foreign_key "lineups", "matches"
  add_foreign_key "match_availabilities", "match_nights"
  add_foreign_key "match_availabilities", "players"
  add_foreign_key "match_nights", "seasons"
  add_foreign_key "match_slots", "match_nights"
  add_foreign_key "matches", "match_nights"
  add_foreign_key "matches", "seasons"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
  add_foreign_key "roster_spots", "players"
  add_foreign_key "roster_spots", "seasons"
  add_foreign_key "roster_spots", "teams"
  add_foreign_key "slot_availabilities", "match_slots"
  add_foreign_key "slot_availabilities", "players"
end
