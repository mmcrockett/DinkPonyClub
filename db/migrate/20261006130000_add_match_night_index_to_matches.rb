class AddMatchNightIndexToMatches < ActiveRecord::Migration[8.1]
  def change
    add_index :matches, :match_night_id
  end
end
