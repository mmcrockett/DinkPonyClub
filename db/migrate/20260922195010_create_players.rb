class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :first_name, limit: 100, null: false
      t.string :last_name, limit: 100, null: false
      t.string :email, limit: 255

      t.timestamps
    end

    add_index :players, :email, unique: true
  end
end
