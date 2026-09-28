# frozen_string_literal: true

# The migration classes below wrap raw tables, not real models - the
# update_columns/update_all calls are one-time backfills with nothing left
# to validate.
# rubocop:disable-next Rails/SkipsModelValidations
class RekeyAvailabilityToMatchNights < ActiveRecord::Migration[8.1]
  class MigrationMatch < ActiveRecord::Base
    self.table_name = 'matches'
  end

  class MigrationMatchAvailability < ActiveRecord::Base
    self.table_name = 'match_availabilities'
  end

  class MigrationMatchSlot < ActiveRecord::Base
    self.table_name = 'match_slots'
  end

  def up
    migrate_match_availabilities
    migrate_match_slots
  end

  def down
    revert_match_availabilities
    revert_match_slots
  end

  private

  def migrate_match_availabilities
    add_reference :match_availabilities, :match_night, null: true, foreign_key: true, index: false
    backfill_match_night_id(MigrationMatchAvailability)
    dedupe(MigrationMatchAvailability, :player_id)
    change_column_null :match_availabilities, :match_night_id, false

    remove_index :match_availabilities, name: 'index_match_availabilities_on_match_and_player'
    remove_foreign_key :match_availabilities, :matches
    remove_column :match_availabilities, :match_id

    add_column :match_availabilities, :status, :string, limit: 10, null: false, default: 'maybe'
    MigrationMatchAvailability.reset_column_information
    MigrationMatchAvailability.where(playing: true).update_all(status: 'in')
    MigrationMatchAvailability.where(playing: false).update_all(status: 'out')
    remove_column :match_availabilities, :playing

    add_index :match_availabilities, %i[match_night_id player_id], unique: true,
                                                                   name: 'index_match_availabilities_on_match_night_and_player'
  end

  def migrate_match_slots
    add_reference :match_slots, :match_night, null: true, foreign_key: true, index: false
    backfill_match_night_id(MigrationMatchSlot)
    dedupe(MigrationMatchSlot, :position)
    change_column_null :match_slots, :match_night_id, false

    remove_index :match_slots, name: 'index_match_slots_on_match_id_and_position'
    remove_foreign_key :match_slots, :matches
    remove_column :match_slots, :match_id

    add_index :match_slots, %i[match_night_id position], unique: true,
                                                         name: 'index_match_slots_on_match_night_and_position'
  end

  def backfill_match_night_id(klass)
    klass.reset_column_information
    MigrationMatch.reset_column_information
    klass.find_each do |record|
      match = MigrationMatch.find(record.match_id)
      record.update_columns(match_night_id: match.match_night_id)
    end
  end

  def dedupe(klass, unique_column)
    klass.reset_column_information
    klass.all.group_by { |record| [record.match_night_id, record.public_send(unique_column)] }.each_value do |group|
      next if group.size <= 1

      group.sort_by(&:id).drop(1).each(&:destroy)
    end
  end

  def revert_match_availabilities
    add_column :match_availabilities, :playing, :boolean, null: false, default: true
    MigrationMatchAvailability.reset_column_information
    MigrationMatchAvailability.where(status: 'in').update_all(playing: true)
    MigrationMatchAvailability.where(status: %w[maybe out]).update_all(playing: false)
    remove_column :match_availabilities, :status

    add_column :match_availabilities, :match_id, :integer
    MigrationMatchAvailability.reset_column_information
    MigrationMatchAvailability.find_each do |record|
      match = MigrationMatch.find_by(match_night_id: record.match_night_id)
      record.update_columns(match_id: match&.id)
    end
    change_column_null :match_availabilities, :match_id, false
    add_foreign_key :match_availabilities, :matches
    add_index :match_availabilities, %i[match_id player_id], unique: true,
                                                             name: 'index_match_availabilities_on_match_and_player'

    remove_index :match_availabilities, name: 'index_match_availabilities_on_match_night_and_player'
    remove_foreign_key :match_availabilities, :match_nights
    remove_column :match_availabilities, :match_night_id
  end

  def revert_match_slots
    add_column :match_slots, :match_id, :integer
    MigrationMatchSlot.reset_column_information
    MigrationMatchSlot.find_each do |record|
      match = MigrationMatch.find_by(match_night_id: record.match_night_id)
      record.update_columns(match_id: match&.id)
    end
    change_column_null :match_slots, :match_id, false
    add_foreign_key :match_slots, :matches
    add_index :match_slots, %i[match_id position], unique: true,
                                                   name: 'index_match_slots_on_match_id_and_position'

    remove_index :match_slots, name: 'index_match_slots_on_match_night_and_position'
    remove_foreign_key :match_slots, :match_nights
    remove_column :match_slots, :match_night_id
  end
end
