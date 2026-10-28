class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :schools, :name, unique: true
  end
end
