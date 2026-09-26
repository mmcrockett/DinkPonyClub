class CreateClubhouseRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :clubhouse_seasons do |t|
      t.string :slug, null: false
      t.json :payload, null: false
      t.integer :lock_version, default: 0, null: false
      t.boolean :current, default: false, null: false
      t.timestamps
    end
    add_index :clubhouse_seasons, :slug, unique: true
    create_table :clubhouse_photos do |t|
      t.references :player, null: false, foreign_key: true
      t.string :caption, limit: 500, default: '', null: false
      t.string :content_type, null: false
      t.binary :image_data, limit: 8.megabytes, null: false
      t.timestamps
    end
  end
end
