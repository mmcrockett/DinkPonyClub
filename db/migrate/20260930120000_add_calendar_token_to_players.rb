# frozen_string_literal: true

# MySQL DDL is not transactional, so every step tolerates a re-run after a
# partial apply.
class AddCalendarTokenToPlayers < ActiveRecord::Migration[8.1]
  class MigrationPlayer < ActiveRecord::Base
    self.table_name = 'players'
  end

  def up
    add_column :players, :calendar_token, :string, limit: 64, if_not_exists: true

    MigrationPlayer.reset_column_information
    MigrationPlayer.where(calendar_token: nil).find_each do |player|
      player.update_columns(calendar_token: SecureRandom.urlsafe_base64(24)) # rubocop:disable Rails/SkipsModelValidations
    end

    change_column_null :players, :calendar_token, false
    add_index :players, :calendar_token, unique: true, if_not_exists: true
  end

  def down
    remove_index :players, :calendar_token, if_exists: true
    remove_column :players, :calendar_token, if_exists: true
  end
end
