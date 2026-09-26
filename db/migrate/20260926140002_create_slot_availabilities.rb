# frozen_string_literal: true

class CreateSlotAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :slot_availabilities do |t|
      t.references :match_slot, null: false, foreign_key: true, index: false
      t.references :player, null: false, foreign_key: true
      t.string :preference, limit: 20, null: false, default: 'meh'

      t.timestamps
    end

    add_index :slot_availabilities, %i[match_slot_id player_id], unique: true,
                                                                 name: 'index_slot_availabilities_on_slot_and_player'
  end
end
