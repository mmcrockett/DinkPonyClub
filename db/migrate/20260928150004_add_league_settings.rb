# frozen_string_literal: true

class AddLeagueSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :seasons, bulk: true do |t|
      t.decimal :sweep_bonus, precision: 3, scale: 1, null: false, default: 0.5
      t.text :rules
    end

    add_column :roster_spots, :draft_rank, :string, limit: 10

    change_table :players, bulk: true do |t|
      t.string :phone, limit: 40
      t.string :contact_email, limit: 254
    end
  end
end
