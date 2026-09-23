class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :lineup, null: false, foreign_key: true, index: false
      t.integer :number, null: false
      t.integer :home_score, null: false
      t.integer :away_score, null: false

      t.timestamps
    end

    add_index :games, %i[lineup_id number], unique: true
  end
end
