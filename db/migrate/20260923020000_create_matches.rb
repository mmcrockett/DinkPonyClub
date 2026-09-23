class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :season, null: false, foreign_key: true, index: false
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.date :played_on
      t.integer :home_match_points, null: false, default: 0
      t.integer :away_match_points, null: false, default: 0
      t.integer :home_points_scored, null: false, default: 0
      t.integer :away_points_scored, null: false, default: 0

      t.timestamps
    end

    add_index :matches, %i[season_id played_on]
  end
end
