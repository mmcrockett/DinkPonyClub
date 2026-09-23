class AddGoogleAuthToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :avatar_url, :string, limit: 512
    add_column :players, :google_uid, :string, limit: 255
    add_column :players, :last_signed_in_at, :datetime

    add_index :players, :google_uid, unique: true
  end
end
