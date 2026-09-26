# frozen_string_literal: true

class CreateMatchAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :match_availabilities do |t|
      t.references :match, null: false, foreign_key: true, index: false
      t.references :player, null: false, foreign_key: true
      t.boolean :playing, null: false, default: true

      t.timestamps
    end

    add_index :match_availabilities, %i[match_id player_id], unique: true,
                                                             name: 'index_match_availabilities_on_match_and_player'
  end
end
