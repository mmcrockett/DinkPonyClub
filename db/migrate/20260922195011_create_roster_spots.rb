class CreateRosterSpots < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_spots do |t|
      t.references :season, null: false, foreign_key: true, index: false
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.boolean :captain, null: false, default: false

      t.timestamps
    end

    add_index :roster_spots, %i[season_id player_id], unique: true,
                                                      name: 'index_roster_spots_on_season_and_player'
    add_index :roster_spots, %i[season_id team_id]
  end
end
