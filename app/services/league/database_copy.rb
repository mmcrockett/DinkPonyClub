# frozen_string_literal: true

module League
  class DatabaseCopy
    class Error < StandardError; end

    class Source < ApplicationRecord
      self.abstract_class = true
    end

    class Target < ApplicationRecord
      self.abstract_class = true
    end

    SKIPPED_TABLES = %w[ar_internal_metadata schema_migrations].freeze
    BATCH_SIZE = 1000

    def initialize(source:, target:)
      @source = connect(Source, source)
      @target = connect(Target, target)
    end

    def call
      verify_schema_versions!
      @target.disable_referential_integrity do
        @target.transaction { tables.each { |table| replace(table) } }
      end
      verify_counts
    end

    private

    def connect(klass, spec)
      config = spec.respond_to?(:adapter) ? spec : find_config(spec)
      klass.establish_connection(config)
      klass.lease_connection
    end

    def find_config(name)
      ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name.to_s) ||
        raise(Error, "No #{Rails.env} database config named #{name}")
    end

    def tables
      @tables ||= @source.tables - SKIPPED_TABLES
    end

    def verify_schema_versions!
      source_versions, target_versions = [@source, @target].map { |db| versions(db) }
      return if source_versions == target_versions

      raise Error, 'Schema versions differ; migrate both databases before copying'
    end

    def versions(connection)
      connection.select_values('SELECT version FROM schema_migrations').sort
    end

    def replace(table)
      @target.execute("DELETE FROM #{@target.quote_table_name(table)}")
      offset = 0

      loop do
        result = @source.select_all(page_sql(table, offset))
        insert(table, result)
        offset += BATCH_SIZE
        break if result.length < BATCH_SIZE
      end
    end

    def page_sql(table, offset)
      order = @source.primary_key(table)
      order_by = order ? " ORDER BY #{@source.quote_column_name(order)}" : ''
      "SELECT * FROM #{@source.quote_table_name(table)}#{order_by} LIMIT #{BATCH_SIZE} OFFSET #{offset}"
    end

    def insert(table, result)
      return if result.empty?

      columns = result.columns.map { |name| @target.quote_column_name(name) }.join(', ')
      values = result.rows.map { |row| "(#{row.map { |value| @target.quote(value) }.join(', ')})" }.join(', ')
      @target.execute("INSERT INTO #{@target.quote_table_name(table)} (#{columns}) VALUES #{values}")
    end

    def verify_counts
      mismatches = tables.filter_map do |table|
        source, target = [@source, @target].map { |db| count(db, table) }
        "#{table}: #{source} != #{target}" if source != target
      end
      raise Error, "Row counts differ - #{mismatches.join(', ')}" if mismatches.any?

      tables.index_with { |table| count(@target, table) }
    end

    def count(connection, table)
      connection.select_value("SELECT COUNT(*) FROM #{connection.quote_table_name(table)}").to_i
    end
  end
end
