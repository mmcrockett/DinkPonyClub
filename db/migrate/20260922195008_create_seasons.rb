class CreateSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.string :name, limit: 100, null: false
      t.date :starts_on
      t.date :ends_on

      t.timestamps
    end

    add_index :seasons, :name, unique: true
  end
end
