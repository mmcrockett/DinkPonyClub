class CreateCourtAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :court_assignments do |t|
      t.references :match, null: false, foreign_key: true
      t.references :match_slot, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :court, null: false
      t.timestamps
    end
    add_index :court_assignments, %i[match_id position], unique: true
    add_index :court_assignments, %i[match_slot_id court], unique: true
  end
end
