class CreateFeesAndCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :fees do |t|
      t.references :season, null: false, foreign_key: true
      t.string :name, limit: 100, null: false
      t.integer :amount_cents, null: false
      t.boolean :applies_to_all, null: false, default: false
      t.timestamps
      t.index %i[season_id name], unique: true
    end

    create_table :charges do |t|
      t.references :roster_spot, null: false, foreign_key: true
      t.references :fee, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :paid_cents, null: false, default: 0
      t.timestamps
      t.index %i[roster_spot_id fee_id], unique: true
    end
  end
end
