class AddLineCounts < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :lines_per_match, :integer, null: false, default: 5
    add_column :match_nights, :lines_count, :integer
  end
end
