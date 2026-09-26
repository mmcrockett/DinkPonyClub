# frozen_string_literal: true

class CreateMatchSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :match_slots do |t|
      t.references :match, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.datetime :starts_at, null: false

      t.timestamps
    end

    add_index :match_slots, %i[match_id position], unique: true,
                                                   name: 'index_match_slots_on_match_id_and_position'
  end
end
