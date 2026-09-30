# frozen_string_literal: true

class CreateMatchNights < ActiveRecord::Migration[8.1]
  def change
    create_table :match_nights do |t|
      t.references :season, null: false, foreign_key: true, index: false
      t.date :played_on, null: false
      t.string :label, limit: 60, null: false
      t.string :venue, limit: 150
      t.text :notes
      t.boolean :canceled, null: false, default: false
      t.boolean :playoff, null: false, default: false

      t.timestamps

      # Inside create_table, not a trailing add_index: MySQL needs this index
      # for the season_id FK, so reversing a trailing add_index fails.
      t.index %i[season_id played_on]
    end
  end
end
