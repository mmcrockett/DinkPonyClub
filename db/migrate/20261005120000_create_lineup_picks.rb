class CreateLineupPicks < ActiveRecord::Migration[8.1]
  def change
    create_table :lineup_picks do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :seat, null: false
      t.timestamps
    end

    add_index :lineup_picks, %i[match_id team_id position seat], unique: true, name: 'index_lineup_picks_on_slot'
    add_index :lineup_picks, %i[match_id player_id], unique: true
  end
end
