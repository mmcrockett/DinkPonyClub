require 'test_helper'

module League
  class DatabaseCopyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @path = Rails.root.join('tmp', "database_copy_test_#{Process.pid}.sqlite3").to_s
      @source = ActiveRecord::Base.connection_db_config
      @target = ActiveRecord::DatabaseConfigurations::HashConfig.new(
        Rails.env, 'copy_target', { adapter: 'sqlite3', database: @path }
      )
      ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(@target) do
        ActiveRecord::Tasks::DatabaseTasks.load_schema(@target, :ruby, Rails.root.join('db/schema.rb').to_s)
      end
    end

    teardown do
      DatabaseCopy::Target.remove_connection
      FileUtils.rm_f(@path)
    end

    test 'copies every row with its id into the target' do
      DatabaseCopy.new(source: @source, target: @target).call

      assert_equal Team.order(:id).pluck(:id, :name), target_rows('SELECT id, name FROM teams ORDER BY id')
    end

    test 'returns row counts per table' do
      counts = DatabaseCopy.new(source: @source, target: @target).call

      assert_equal Player.count, counts['players']
    end

    test 'replaces rows already in the target' do
      DatabaseCopy.new(source: @source, target: @target).call
      DatabaseCopy::Target.lease_connection.execute("UPDATE teams SET name = 'Stale ' || id")
      DatabaseCopy.new(source: @source, target: @target).call

      assert_equal Team.order(:id).pluck(:name), target_rows('SELECT name FROM teams ORDER BY id').flatten
    end

    test 'ignores the baseline schema version 0 when comparing schema versions' do
      DatabaseCopy::Target.establish_connection(@target)
      DatabaseCopy::Target.lease_connection.execute("INSERT INTO schema_migrations (version) VALUES ('0')")

      assert_nothing_raised { DatabaseCopy.new(source: @source, target: @target).call }
    end

    test 'refuses to copy when schema versions differ' do
      DatabaseCopy::Target.establish_connection(@target)
      DatabaseCopy::Target.lease_connection.execute("INSERT INTO schema_migrations (version) VALUES ('1')")

      error = assert_raises(DatabaseCopy::Error) { DatabaseCopy.new(source: @source, target: @target).call }

      assert_match(/Schema versions differ/, error.message)
    end

    private

    def target_rows(sql)
      DatabaseCopy::Target.lease_connection.select_rows(sql)
    end
  end
end
