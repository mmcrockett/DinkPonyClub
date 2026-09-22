class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, limit: 100, null: false
      t.string :tagline, limit: 200

      t.timestamps
    end

    add_index :teams, :name, unique: true
  end
end
