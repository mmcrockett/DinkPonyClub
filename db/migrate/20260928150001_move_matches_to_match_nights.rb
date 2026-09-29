# frozen_string_literal: true

# The migration classes below wrap raw tables, not real models - the four
# update_columns calls are one-time backfills with nothing left to validate.
# rubocop:disable-next Rails/SkipsModelValidations
class MoveMatchesToMatchNights < ActiveRecord::Migration[8.1]
  class MigrationMatch < ActiveRecord::Base
    self.table_name = 'matches'
  end

  class MigrationMatchNight < ActiveRecord::Base
    self.table_name = 'match_nights'
  end

  DROPPED_COLUMNS = %i[played_on home_match_points away_match_points
                       home_points_scored away_points_scored].freeze

  # Each step is guarded so a partially-applied run can be re-run to completion.
  # MySQL commits DDL immediately, so a failure mid-migration leaves the earlier
  # steps applied with no schema_migrations row to record them.
  def up
    add_reference :matches, :match_night, null: true, foreign_key: true, index: false unless
      column_exists?(:matches, :match_night_id)

    backfill_match_nights

    change_column_null :matches, :match_night_id, false

    swap_season_index
    DROPPED_COLUMNS.each { |column| remove_column :matches, column if column_exists?(:matches, column) }
  end

  def down
    add_column :matches, :played_on, :date
    add_column :matches, :home_match_points, :integer, null: false, default: 0
    add_column :matches, :away_match_points, :integer, null: false, default: 0
    add_column :matches, :home_points_scored, :integer, null: false, default: 0
    add_column :matches, :away_points_scored, :integer, null: false, default: 0

    MigrationMatch.reset_column_information
    MigrationMatch.find_each do |match|
      night = MigrationMatchNight.find(match.match_night_id)
      match.update_columns(played_on: night.played_on)
    end

    add_index :matches, %i[season_id played_on]
    remove_index :matches, :season_id if index_exists?(:matches, :season_id)
    remove_foreign_key :matches, :match_nights
    remove_column :matches, :match_night_id
  end

  private

  # MySQL requires an index covering an FK column, and the composite index is
  # the only one covering season_id - so the replacement has to exist first.
  def swap_season_index
    add_index :matches, :season_id unless index_exists?(:matches, :season_id)
    return unless index_exists?(:matches, %i[season_id played_on])

    remove_index :matches, %i[season_id played_on]
  end

  def backfill_match_nights
    MigrationMatch.reset_column_information
    MigrationMatch.all.group_by(&:season_id).each_value { |matches| backfill_season_nights(matches) }
  end

  def backfill_season_nights(matches)
    night_groups(matches).each_with_index { |(played_on, group_matches), index| create_night!(played_on, group_matches, index) }
  end

  def night_groups(matches)
    dated, undated = matches.partition(&:played_on)
    dated.group_by(&:played_on).sort_by { |played_on, _| played_on } +
      undated.sort_by(&:id).map { |match| [Date.current, [match]] }
  end

  def create_night!(played_on, group_matches, index)
    night = MigrationMatchNight.create!(season_id: group_matches.first.season_id, played_on: played_on,
                                        label: "Week #{index + 1}")
    group_matches.each { |match| match.update_columns(match_night_id: night.id) }
  end
end
