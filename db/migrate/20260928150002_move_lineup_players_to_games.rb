# frozen_string_literal: true

# The migration classes below wrap raw tables, not real models - the
# update_columns calls are one-time backfills with nothing left to validate.
# rubocop:disable-next Rails/SkipsModelValidations
class MoveLineupPlayersToGames < ActiveRecord::Migration[8.1]
  class MigrationGame < ActiveRecord::Base
    self.table_name = 'games'
  end

  class MigrationLineup < ActiveRecord::Base
    self.table_name = 'lineups'
  end

  def up
    change_table :games, bulk: true do |t|
      t.references :home_player_a, null: true, foreign_key: { to_table: :players }
      t.references :home_player_b, null: true, foreign_key: { to_table: :players }
      t.references :away_player_a, null: true, foreign_key: { to_table: :players }
      t.references :away_player_b, null: true, foreign_key: { to_table: :players }
    end

    backfill_game_players

    change_column_null :games, :home_player_a_id, false
    change_column_null :games, :home_player_b_id, false
    change_column_null :games, :away_player_a_id, false
    change_column_null :games, :away_player_b_id, false

    remove_foreign_key :lineups, column: :home_player_one_id
    remove_foreign_key :lineups, column: :home_player_two_id
    remove_foreign_key :lineups, column: :away_player_one_id
    remove_foreign_key :lineups, column: :away_player_two_id
    remove_index :lineups, :home_player_one_id
    remove_index :lineups, :home_player_two_id
    remove_index :lineups, :away_player_one_id
    remove_index :lineups, :away_player_two_id

    change_table :lineups, bulk: true do |t|
      t.remove :home_player_one_id, :home_player_two_id, :away_player_one_id, :away_player_two_id
    end
  end

  def down
    change_table :lineups, bulk: true do |t|
      t.references :home_player_one, null: true, foreign_key: { to_table: :players }
      t.references :home_player_two, null: true, foreign_key: { to_table: :players }
      t.references :away_player_one, null: true, foreign_key: { to_table: :players }
      t.references :away_player_two, null: true, foreign_key: { to_table: :players }
    end

    MigrationLineup.reset_column_information
    MigrationGame.reset_column_information
    MigrationLineup.find_each do |lineup|
      game = MigrationGame.where(lineup_id: lineup.id).first
      next unless game

      lineup.update_columns(
        home_player_one_id: game.home_player_a_id, home_player_two_id: game.home_player_b_id,
        away_player_one_id: game.away_player_a_id, away_player_two_id: game.away_player_b_id
      )
    end

    change_column_null :lineups, :home_player_one_id, false
    change_column_null :lineups, :home_player_two_id, false
    change_column_null :lineups, :away_player_one_id, false
    change_column_null :lineups, :away_player_two_id, false

    change_table :games, bulk: true do |t|
      t.remove :home_player_a_id, :home_player_b_id, :away_player_a_id, :away_player_b_id
    end
  end

  private

  def backfill_game_players
    MigrationGame.reset_column_information
    MigrationLineup.reset_column_information
    MigrationGame.find_each do |game|
      lineup = MigrationLineup.find(game.lineup_id)
      game.update_columns(
        home_player_a_id: lineup.home_player_one_id, home_player_b_id: lineup.home_player_two_id,
        away_player_a_id: lineup.away_player_one_id, away_player_b_id: lineup.away_player_two_id
      )
    end
  end
end
