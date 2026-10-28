class AddSchoolToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :school, foreign_key: true, null: true
  end
end
