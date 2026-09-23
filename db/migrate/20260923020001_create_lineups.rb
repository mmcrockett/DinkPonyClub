class CreateLineups < ActiveRecord::Migration[8.1]
  def change
    create_table :lineups do |t|
      t.references :match, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.references :home_player_one, null: false, foreign_key: { to_table: :players }
      t.references :home_player_two, null: false, foreign_key: { to_table: :players }
      t.references :away_player_one, null: false, foreign_key: { to_table: :players }
      t.references :away_player_two, null: false, foreign_key: { to_table: :players }

      t.timestamps
    end

    add_index :lineups, %i[match_id position], unique: true,
                                               name: 'index_lineups_on_match_id_and_position'
  end
end
