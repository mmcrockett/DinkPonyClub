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

ActiveRecord::Schema[8.1].define(version: 2026_09_22_195011) do
  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", limit: 255
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_players_on_email", unique: true
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

  add_foreign_key "roster_spots", "players"
  add_foreign_key "roster_spots", "seasons"
  add_foreign_key "roster_spots", "teams"
end
