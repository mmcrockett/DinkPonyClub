class AddUniqueStartsAtIndexToMatchSlots < ActiveRecord::Migration[8.1]
  def change
    add_index :match_slots, %i[match_night_id starts_at], unique: true,
                                                          name: 'index_match_slots_on_match_night_and_starts_at'
  end
end
